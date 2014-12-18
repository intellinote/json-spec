EventEmitter = require('events').EventEmitter
fs           = require 'fs'
Util         = require('inote-util').Util

SINGLE_LINE_REGEXP = /\n/
ISO_8601_REGEXP    = Util.iso_8601_regexp()
URI_REGEXP         = /^[a-z]+\:.+/

class ErrorListener
  _error_count: 0
  error_count:()=>@_error_count
  has_error:()=>@_error_count > 0
  on_error:(type,message,tail...)=>
    throw new Error("Not implemented")
  on_errors:(errors)=>
    for error in errors
      @on_error(error...)

class ErrorReporter extends ErrorListener
  on_error:(type,message,tail...)=>
    console.error type,message,tail...
    @_error_count++

class ErrorCollector extends ErrorListener
  errors: []
  on_error:(type,message,tail...)=>
    @errors.push [type,message,tail...]

enum_to_string = (options)->
  if options.length is 1
    return options[0]
  else
    return "one of " + Util.smart_join(options,", "," or ")

class JSONSpec extends EventEmitter

  load_spec:(file)=>
    try
      src = fs.readFileSync file
    catch err
      throw new Error("Error loading JSON file at \"#{file}\".",err)
    try
      return @parse_spec src.toString()
    catch err
      throw err

  parse_spec:(src)=>
    if typeof src is 'string'
      try
        src = JSON.parse(src)
      catch err
        throw new Error("Error parsing JSON document.",err)
    return @normalize(src)

  normalize:(src)=>
    if src.datatype?
      return @_normalize_attributes(src)
    else
      dst = {}
      for k,v of src
        dst[k] = @_normalize_attributes(v)
      return dst

  _normalize_attributes:(src)=>
    if Array.isArray(src)
      dst = []
      for s in src
        dst.push @_normalize_attributes(s)
      return dst
    else
      dst = {}
      for k,v of src
        switch k
          when 'datatype','default','description'
            dst[k] = v
          when 'attributes'
            dst[k] = @normalize(v)
          when 'items'
            dst[k] = @_normalize_attributes(v)
          when 'enum','constraints','format'
            unless Array.isArray(v)
              v = [ v ]
            if k is 'format'
              for e in v
                if typeof e is 'object'
                  if e.matching? and typeof e.matching is 'string'
                    e.matching = new RegExp(e.matching)
                  else if e['not-matching']? and typeof e['not-matching'] is 'string'
                    e['not-matching'] = new RegExp(e['not-matching'])
            dst[k] = v
          when 'range'
            if v.length < 3
              v.push "inclusive"
            dst[k] = v
          else
            err = new Error("Specification Error: Found unexpected parameter \"#{k}\" = \"#{v}\" in \"#{src}\".")
            console.error err
            throw err
      if dst.items? and not dst.datatype is 'array'
        err = new Error("Specification Error: Found 'items' for non-array datatype \"#{dst.datatype}\".")
        console.error err
        throw err
      return dst

  validate:(spec,data,path=[],error_listener)=>
    error_listener ?= new ErrorReporter()
    valid = true
    path ?= []
    if spec.datatype?
      if not @_validate_attribute(spec,data,path,error_listener)
        valid = false
      return valid
    else
      for k,v of data
        p = [].concat(path)
        p.push(k)
        s = spec[k] ? spec['*']
        if s?
          if not @_validate_attribute(s,v,p,error_listener)
            valid = false
        else
          @_emit_validation_error(error_listener,data,spec,'unexpected',path,v,k)

  _validate_attribute:(spec,attr,path,error_listener)=>
    if Array.isArray(spec)
      error_collector = new ErrorCollector()
      for alt,i in spec
        if @_validate_attribute(alt,attr,path,error_collector)
          return true
      @_emit_validation_error(error_listener,attr,spec,'no-matching-alt',path,attr,"\n\t"+error_collector.errors.join("\n\t"))
      return false
    else
      valid = true
      unless attr?
        if spec?.constraints? and 'required' in spec.constraints
          @_emit_validation_error(error_listener,attr,spec,'required',path,attr)
          valid = false
        else
          @_debug "ok","(null)",path
      else
        # DATATYPE
        switch spec.datatype
          when 'string'
            unless typeof attr is 'string'
              @_emit_validation_error(error_listener,attr,spec,'datatype',path,attr,'string')
              valid = false
            else
              @_debug "ok","(string)",path
          when 'number'
            unless typeof attr is 'number'
              @_emit_validation_error(error_listener,attr,spec,'datatype',path,attr,'number')
              valid = false
            else
              @_debug "ok","(number)",path
          when 'array'
            unless Array.isArray(attr)
              @_emit_validation_error(error_listener,attr,spec,'datatype',path,attr,'array')
              valid = false
            else
              @_debug "ok","(array)",path
              for elt,i in attr
                p = [].concat(path)
                p.push "[#{i}]"
                if not @_validate_attribute(spec.items,elt,p,error_listener)
                  valid = false
          when 'map'
            unless typeof attr is 'object'
              @_emit_validation_error(error_listener,attr,spec,'datatype',path,attr,'object')
            else
              @_debug "ok","(map)",path,spec
              for k,v of attr
                p = [].concat(path)
                p.push(k)
                s = spec.attributes[k] ? spec.attributes['*']
                if s?
                  if not @_validate_attribute(s,v,p,error_listener)
                    valid = false
                else
                  valid = false
                  @_emit_validation_error(error_listener,data,spec,'unexpected',path,v,k)
          else
            @_emit_validation_error(error_listener,attr,spec,'not-supported',path,spec.datatype)
            valid = false
        # ENUM
        if spec.enum?
          unless attr in spec.enum
            @_emit_validation_error(error_listener,attr,spec,'enum',path,attr,spec.enum)
            valid = false
          else
            @_debug "ok","(enum)",path
        # RANGE
        if spec.range?
          if spec.range.length is 2 or spec.range[2] is 'inclusive'
            unless spec.range[0] <= attr <= spec.range[1]
              @_emit_validation_error(error_listener,attr,spec,"range",path,attr,spec.range)
              valid = false
            else
              @_debug "ok","(range)",path
          else
            unless spec.range[0] < attr < spec.range[1]
              @_emit_validation_error(error_listener,attr,spec,"range",path,attr,spec.range)
              valid = false
            else
              @_debug "ok","(range)",path
        # FORMAT
        if spec.format?
          for f in spec.format
            if typeof f is 'string'
              switch f
                when 'singleline'
                  if SINGLE_LINE_REGEXP.test attr
                    @_emit_validation_error(error_listener,attr,spec,"format-forbidden",path,attr,SINGLE_LINE_REGEXP)
                    valid = false
                  else
                    @_debug "ok","(singleline)",path
                when 'iso8601date'
                  unless ISO_8601_REGEXP.test attr
                    @_emit_validation_error(error_listener,attr,spec,"format-required",path,attr,ISO_8601_REGEXP)
                    valid = false
                  else
                    @_debug "ok","(iso8601date)",path
                when 'uri'
                  unless URI_REGEXP.test attr
                    @_emit_validation_error(error_listener,attr,spec,"format-required",path,attr,URI_REGEXP)
                    valid = false
                  else
                    @_debug "ok","(uri)",path
            else if f.matching?
              unless f.matching.test attr
                @_emit_validation_error(error_listener,attr,spec,"format-required",path,attr,f.matching)
            else if f['not-matching']?
              if f['not-matching'].test attr
                @_emit_validation_error(error_listener,attr,spec,"format-forbidden",path,attr,f['not-matching'])

      @_debug "returning",valid,path
      return valid

  _debug:(type,message,tail...)=>
    # console.log type,message,tail...

  _emit_validation_error:(listener,data,spec,message_id,path,value,expected)=>
    message = @_make_validation_error_message(data,spec,message_id,path,value,expected)
    if message_id is 'no-matching-alt'
      listener?.on_error "validation-error",message,expected
    else
      listener?.on_error "validation-error",message

  _make_validation_error_message:(data,spec,message_id,path,value,expected)=>
    path = "`#{path.join '.'}`"
    switch message_id
      when 'required'
        message = "Required attribute not found at #{path}."
      when 'datatype'
        message = "Expected datatype \"#{expected}\" but found #{typeof value} at #{path}."
      when 'enum'
        message = "Expected " + enum_to_string(expected.map((x)->"\"#{x}\"")) + " but found \"#{value}\" at #{path}."
      when 'range'
        message = "Expected value between #{expected[0]} and #{expected[1]} (#{expected[2] ? 'inclusive'}) but found #{value} at #{path}."
      when 'format-required'
        message = "Expected value to match #{expected} but found \"#{value}\" at #{path}."
      when 'format-forbidden'
        message = "Expected value not to match #{expected} but found \"#{value}\" at #{path}."
      when 'unexpected'
        message = "Unexpected attribute #{expected} at #{path}."
      when 'no-matching-alt'
        message = "No matching alternative at #{path}."
      else
        message = "Validation error (#{message_id})."
        if expected?
          message += " Expected \"#{expected}\"."
        if value?
          message += " Found \"#{JSON.stringify(value)}\"."
        message += " At #{path}"
    return message

exports.JSONSpec = JSONSpec

if require.main is module
  if process.argv.length < 3 or /^-?-?h(elp)?$/.test process.argv[2]
    path = require 'path'
    console.error "Use: #{path.basename(process.argv[1])} validate SPEC.JSON DATA.JSON"
    console.error " or: cat DATA.JSON | #{path.basename(process.argv[1])} validate SPEC.JSON"
    process.exit(1)
  else
    json_spec = new JSONSpec()
    spec = json_spec.load_spec process.argv[3]
    switch process.argv[2]
      when 'validate'
        if process.argv.length >= 4
          data = Util.load_json_file_sync(process.argv[4])
        else
          data = Util.load_json_stdin_sync()
        unless json_spec.validate(spec,data)
          process.exit(2)
      when 'normalize'
        console.log JSON.stringify(spec,null,2)
      when 'to-text'
        visit = (key,elt,indent)=>
          if Array.isArray(elt)
            console.log "#{indent} (alternative formats allowed)"
            indent += "  "
            for e,i in elt
              visit("(alternative ##{i+1})",e,indent)
          else
            parts = [ ]
            if indent.length > 0
              parts.push indent
            if key?
              parts.push key
              parts.push " - "
            if elt.description?
              parts.push elt.description + " "
            bracketed = []
            if elt.datatype?
              bracketed.push elt.datatype
            if elt.format?
              bracketed.push (elt.format.map (x)->
                if x.matching?
                  return "matching #{x.matching}"
                else if x['not-matching']
                  return "not matching #{x['not-matching']}"
                else
                  return x).join(',')
            if elt.enum?
              bracketed.push enum_to_string(elt.enum.map (x)->"\"#{x}\"")
            if elt.constraints?
              bracketed.push  elt.constraints.join(', ')
            if bracketed.length > 0
              parts.push "[#{bracketed.join(', ')}]"
            console.log parts.join("")
            if elt.attributes?
              for k,v of elt.attributes
                visit(k,v,indent+"  ")
            if elt.items?
                visit("(elements)",elt.items,indent+"  ")
        visit(null,spec,"")

      when 'to-markdown'
        visit = (key,elt,indent)=>
          parts = [ ]
          if indent.length > 0
            parts.push indent
            parts.push " * "
          if key?
            if key is "*"
              parts.push "*(any key)*"
            else if key is "(elements)"
              parts.push "*(elements)*"
            else
              parts.push "**`"+key+"`**"
            parts.push " - "
          else
            parts.push "# "
          if Array.isArray(elt)
            parts.push "(alternative formats allowed)"
            console.log parts.join("")
            indent += "  "
            for e,i in elt
              visit("(alternative ##{i+1})",e,indent)
          else
            if elt.description?
              parts.push "*"+elt.description + "* "
            bracketed = []
            if elt.datatype?
              bracketed.push elt.datatype
            if elt.format?
              bracketed.push (elt.format.map (x)->
                if x.matching?
                  return "matching `#{x.matching}`"
                else if x['not-matching']
                  return "not matching `#{x['not-matching']}`"
                else
                  return x).join(', ')
            if elt.enum?
              bracketed.push enum_to_string(elt.enum.map (x)->"\"#{x}\"")
            if elt.range?
              bracketed.push "between #{elt.range[0]} and #{elt.range[1]}, #{elt.range[2]}"
            if elt.constraints?
              bracketed.push  elt.constraints.join(', ')
            if elt.default?
              bracketed.push "defaults to `#{elt.default}`"
            if bracketed.length > 0
              parts.push "<small style=\"color:#666;\">[#{bracketed.join(', ')}]</small>"
            console.log parts.join("")
            if elt.attributes?
              for k,v of elt.attributes
                visit(k,v,indent+"  ")
            if elt.items?
                visit("(elements)",elt.items,indent+"  ")
        visit(null,spec,"")
