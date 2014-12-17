EventEmitter = require('events').EventEmitter

SINGLE_LINE_REGEXP = /\n/
ISO_8601_REGEXP= /^(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})(\.\d{3})?(([A-Z]+)|([+-]\d{2}\:\d{2}))$/
URI_REGEXP = /^[a-z]+\:.+/

class JSONSpec extends EventEmitter

  normalize:(src)=>
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
          when 'datatype','default'
            dst[k] = v
          when 'attributes'
            dst[k] = @normalize(v)
          when 'items'
            dst[k] = @_normalize_attributes(v)
          when 'enum','constraints','format'
            unless Array.isArray(v)
              v = [ v ]
            dst[k] = v
          when 'range'
            if v.length < 3
              v.push "inclusive"
            dst[k] = v
          else
            @_emit_error_message "specification-error","Found unexpected parameter \"#{k}\"."
      if dst.items? and not dst.datatype is 'array'
        @_emit_error_message "specification-error","Found 'items' for non-array datatype \"#{dst.datatype}\"."
      return dst

  _emit_error_message:(type,message,tail...)=>
    console.error type,message,tail...

  _emit_message:(type,message,tail...)=>
    # console.log type,message,tail...

  _emit_validation_error:(data,spec,message_id,path,value,expected)=>
    path = path.join '.'
    switch message_id
      when 'required'
        message = "Required attribute \"#{expected}\" not found at #{path}."
      when 'datatype'
        message = "Expected datatype \"#{expected}\" but found #{typeof value} at #{path}."
      when 'enum'
        message = "Expected one of #{expected.join(', ')} but found \"#{value}\" at #{path}."
      when 'range'
        message = "Expected value between #{expected[0]} and #{expected[1]} (#{expected[2] ? 'inclusive'}) but found #{value} at #{path}."
      when 'format-required'
        message = "Expected value to match #{expected} but found #{value} at #{path}."
      when 'format-forbidden'
        message = "Expected value not to match #{expected} but found #{value} at #{path}."
      else
        message = "Validation error (#{message_id})."
        if expected?
          message += " Expected \"#{expected}\"."
        if value?
          message += " Found \"#{found}\"."
        message += " At #{path}"
    @_emit_error_message "validation-error",message

  validate:(data,spec,path)=>
    valid = true
    path ?= []
    for k,v of spec
      p = [].concat(path)
      p.push(k)
      if data?[k]?
        if not @_validate_attribute(data[k],v,p)
          valid = false
      else
        if v?.constraints? and 'required' in v.constraints
          @_emit_validation_error(data,spec,'required',p,data)
          valid = false
    return valid

  _validate_attribute:(attr,spec,path)=>
    if Array.isArray(spec)
      for alt,i in spec
        if @_validate_attribute(attr,alt,path)
          return true
      return false
    else
      valid = true
      unless attr?
        if spec?.constraints? and 'required' in spec.constraints
          @_emit_validation_error(attr,spec,'required',path,attr)
          valid = false
        else
          @_emit_message "ok","(null)",path
      else
        # DATATYPE
        switch spec.datatype
          when 'string'
            unless typeof attr is 'string'
              @_emit_validation_error(attr,spec,'datatype',path,attr,'string')
              valid = false
            else
              @_emit_message "ok","(string)",path
          when 'number'
            unless typeof attr is 'number'
              @_emit_validation_error(attr,spec,'datatype',path,attr,'number')
              valid = false
            else
              @_emit_message "ok","(number)",path
          when 'array'
            unless Array.isArray(attr)
              @_emit_validation_error(attr,spec,'datatype',path,attr,'array')
              valid = false
            else
              @_emit_message "ok","(array)",path
              for elt,i in attr
                p = [].concat(path)
                p.push "[#{i}]"
                if not @_validate_attribute(elt,spec.items,p)
                  valid = false
          when 'map'
            unless typeof attr is 'object'
              @_emit_validation_error(attr,spec,'datatype',path,attr,'object')
            else
              @_emit_message "ok","(map)",path
              if spec.attributes?
                for k,v of spec.attributes
                  p = [].concat(path)
                  p.push(k)
                  if not @_validate_attribute(attr[k],v,p)
                    valid = false
          else
            @_emit_validation_error(attr,spec,'not-supported',path,spec.datatype)
            valid = false
        # ENUM
        if spec.enum?
          unless attr in spec.enum
            @_emit_validation_error(attr,spec,'enum',path,attr,spec.enum)
            valid = false
          else
            @_emit_message "ok","(enum)",path
        # RANGE
        if spec.range?
          if spec.range.length is 2 or spec.range[2] is 'inclusive'
            unless spec.range[0] <= attr <= spec.range[1]
              @_emit_validation_error(attr,spec,"range",path,attr,spec.range)
              valid = false
            else
              @_emit_message "ok","(range)",path
          else
            unless spec.range[0] < attr < spec.range[1]
              @_emit_validation_error(attr,spec,"range",path,attr,spec.range)
              valid = false
            else
              @_emit_message "ok","(range)",path
        # FORMAT
        if spec.format?
          for f in spec.format
            switch f
              when 'singleline'
                if SINGLE_LINE_REGEXP.test attr
                  @_emit_validation_error(attr,spec,"format-forbidden",path,attr,SINGLE_LINE_REGEXP)
                  valid = false
                else
                  @_emit_message "ok","(singleline)",path
              when 'iso8601date'
                unless ISO_8601_REGEXP.test attr
                  @_emit_validation_error(attr,spec,"format-required",path,attr,ISO_8601_REGEXP)
                  valid = false
                else
                  @_emit_message "ok","(iso8601date)",path
              when 'uri'
                unless URI_REGEXP.test attr
                  @_emit_validation_error(attr,spec,"format-required",path,attr,URI_REGEXP)
                  valid = false
                else
                  @_emit_message "ok","(uri)",path
      @_emit_message "returning",valid,path
      return valid


################################################################################

json_spec = new JSONSpec()

################################################################################

unique = 'unique'
required = 'required'

string = 'string'
map = 'map'
number = 'number'
array = 'array'

multiline = 'multiline'
singleline = 'singleline'
iso8601date  = 'iso8601date'
uri = 'uri'

################################################################################

id_model = {
  datatype: string
  constraints: [unique,required]
  format: singleline
}

plain_text_model = {
  datatype: string
  format: singleline
}

user_ref_model = {
  datatype: map
  attributes:
    "user-id":
      datatype: string
      constraints: [ required ] # TODO cross-ref requirement
      format: singleline
}

date_model = {
  datatype: string
  format: iso8601date
}

body_model =
  datatype: map
  attributes:
    "text/html":
      datatype: string
      format: multiline
    "text/plain":
      datatype: string
      format: multiline

################################################################################

root =
  note:
    datatype: map
    attributes:
      type:
        datatype: string
        enum: ['task','note']
        default: 'note'
      id: id_model
      title: plain_text_model
      body: body_model
      tags:
        datatype: array
        items: plain_text_model
      created: date_model
      modified:date_model
      creator: user_ref_model
      location:
        datatype: map
        attributes:
          latitude:
            datatype: number
            range: [-90,90]
          longitude:
            datatype: number
            range: [-90,90]
          elevation:
            datatype: number
          resolution:
            datatype: number
          label: plain_text_model
      links:
        datatype: array
        items:
          [
            {
              datatype: map
              attributes:
                relation:
                  datatype: string
                  enum: [ 'attachment' ]
                  constraints: required
                uri:
                  datatype: string
                  format: uri
                  constraints: required
                created: date_model
                modified: date_model
                creator: user_ref_model
            }
            {
              datatype: map
              attributes:
                id: id_model
                relation:
                  datatype: string
                  enum: [ 'comment' ]
                  constraints: required
                created: date_model
                modified: date_model
                creator: user_ref_model
            }
          ]

################################################################################

root = json_spec.normalize(root)

################################################################################

data = note: {
  "type":"task",
  "id":"7514d9ad-b2e5-4c04-7803-c4c283afcf8d",
  "title":"Title of Note",
  "body": {
    "text/html": "<div>Body of note in <b>HTML</b> format.</div>",
  },
  "tags":["set","of-tag","strings"],
  "created":"2014-12-14T18:53:30.807Z",
  "modified":"2014-12-14T18:53:30.807Z",
  "creator":{
    "user-id":"john@example.net"
  },
  "location":{
    "latitude":38.960341,
    "longitude":-77.254459,
    "elevation":1608.6379,
    "resolution":4.771975,
    "label":"Reston Town Center"
  }
  "links": [
    {
      "relation":"attachment",
      "uri":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==",
      "mime-type":"image/jpeg",
      "title":"Photo of My Cat",
      "filename":"cat-photo.jpg",
      "created":"2014-12-14T18:53:30.807Z",
      "modified":"2014-12-14T18:53:30.807Z",
      "creator":{
        "user-id":"john@example.net"
      }
    }
  ]
}

################################################################################

console.log "VALIDATING"
console.log json_spec.validate(data,root)
console.log "DONE"
