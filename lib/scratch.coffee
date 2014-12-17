class JSONSpec
  normalize:(src)=>
    dst = {}
    for k,v of src
      console.log k
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
            console.error "WARNING: Found unexpected parameter \"#{k}\"."
      if dst.items? and not dst.datatype is 'array'
        console.error "WARNING: Found 'items' for non-array datatype \"#{dst.datatype}\"."
      return dst

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
          console.error "WARNING: Required attribute #{k} not found at",p
    return valid

  _validate_attribute:(attr,spec,path)=>
    if Array.isArray(spec)
      console.log "ALTERNATIVES AT",path
      for alt,i in spec
        if @_validate_attribute(attr,alt,path)
          console.log "RETURNING true DUE TO ALT",i
          return true
      console.log "RETURNING false DUE TO NO MATCING ALT"
      return false
    else
      valid = true
      unless attr?
        if spec?.constraints? and 'required' in spec.constraints
          console.error "WARNING: Required attribute not found at",path
          valid = false
        else
          console.log "ok (null) at",path
      else
        # DATATYPE
        switch spec.datatype
          when 'string'
            unless typeof attr is 'string'
              console.error "expected string, found ",typeof attr," at",path
              valid = false
            else
              console.log 'ok (string) at',path
          when 'number'
            unless typeof attr is 'number'
              console.error "expected number, found ",typeof attr," at",path
              valid = false
            else
              console.log 'ok (number) at',path
          when 'array'
            unless Array.isArray(attr)
              console.error "expected array, found ",typeof attr," at",path
              valid = false
            else
              console.log 'ok (array) at',path
              for elt,i in attr
                p = [].concat(path)
                p.push "[#{i}]"
                if not @_validate_attribute(elt,spec.items,p)
                  valid = false
          when 'map'
            unless typeof attr is 'object'
              console.error "expected map, found ",typeof attr," at",path
            else
              console.log 'ok (map) at',path
              if spec.attributes?
                for k,v of spec.attributes
                  p = [].concat(path)
                  p.push(k)
                  if not @_validate_attribute(attr[k],v,p)
                    valid = false
          else
            console.error "datatype ",spec.datatype,"not handled"," at",path
            valid = false
        # ENUM
        if spec.enum?
          unless attr in spec.enum
            console.error "expected one of ",spec.enum,"found", attr," at",path
            valid = false
          else
            console.log "ok (enum) at",path
        # RANGE
        if spec.range?
          if spec.range.length is 2 or spec.range[2] is 'inclusive'
            unless spec.range[0] <= attr <= spec.range[1]
              console.error "expected a value between ",spec.range,"found", attr," at",path
              valid = false
            else
              console.log "ok (range) at",path
          else
            unless spec.range[0] < attr < spec.range[1]
              console.error "expected a value between ",spec.range,"found", attr," at",path
              valid = false
            else
              console.log "ok (range) at",path
        # FORMAT
        if spec.format?
          for f in spec.format
            switch f
              when 'singleline'
                if /\n/.test attr
                  console.error "expected a single-line string at ",path
                  valid = false
                else
                  console.log "ok (singleline) at",path
              when 'iso8601date'
                unless /^(\d{4})-(\d{2})-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})(\.\d{3})?(([A-Z]+)|([+-]\d{2}\:\d{2}))$/.test attr
                  console.error "expected an ISO 8601 formatted date at ",path,"found",attr
                  valid = false
                else
                  console.log "ok (iso8601date) at",path
              when 'uri'
                unless /^[a-z]+\:.+/.test attr
                  console.error "expected a URI at ",path,"found",attr
                  valid = false
                else
                  console.log "ok (uri) at",path
      console.log "RETURNING",valid
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
