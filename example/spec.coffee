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
                id: id_model
                relation:
                  datatype: string
                  enum: [ 'comment' ]
                  constraints: required
                created: date_model
                modified: date_model
                creator: user_ref_model
            }
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
          ]

console.log JSON.stringify(root,null,2)
