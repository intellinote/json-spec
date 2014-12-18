matching = (regex)->
  {'matching':regex.toString()}

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
email = 'email'

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

multiline_plain_text_model = {
  datatype: string
  format: multiline
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

note_model =
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
      items: [
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
            body: body_model
        }
        {
          datatype: map
          attributes:
            filename: plain_text_model
            "mime-type": plain_text_model
            title: plain_text_model
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

person_vcard_model =
  datatype: map
  attributes:
    vcard:
      datatype: string

person_fielded_model =
  datatype: map
  attributes:
    name:
      datatype: map
      attributes:
        given:
          datatype: string
          constraints: required
          format: singleline
        famliy:
          datatype: string
          constraints: required
          format: singleline
    email:
      datatype: array
      items:
        datatype: string
        format: email
    tel:
      datatype: array
      items:
        datatype: map
        attributes:
          work: plain_text_model
          cell: plain_text_model
          home: plain_text_model
          fax: plain_text_model

person_model = [ person_vcard_model, person_fielded_model ]

workspace_model =
  datatype: map
  attributes:
    id: id_model
    name: plain_text_model
    description: multiline_plain_text_model
    created: date_model
    modified:date_model
    creator: user_ref_model
    notes:
      datatype: array
      items: note_model
    people:
      datatype: map
      attributes:
        '*': person_model

meta_model =
  datatype: map
  constraints: required
  attributes:
    version:
      datatype: string
      constraints: required
      format:  matching "^[0-9]+\.[0-9]+\.[0-9]+$"
    generated: date_model
    generator: plain_text_model
    source: plain_text_model

# root = note:note_model

root =
  datatype: map
  attributes:
    "meta-data": meta_model
    workspaces:
      datatype: array
      items: workspace_model


################################################################################

# root =
#   note:
#     datatype: map
#     attributes:
#       type:
#         datatype: string
#         enum: ['task','note']
#         default: 'note'
#       id: id_model
#       title: plain_text_model
#       body: body_model
#       tags:
#         datatype: array
#         items: plain_text_model
#       created: date_model
#       modified:date_model
#       creator: user_ref_model
#       location:
#         datatype: map
#         attributes:
#           latitude:
#             datatype: number
#             range: [-90,90]
#           longitude:
#             datatype: number
#             range: [-90,90]
#           elevation:
#             datatype: number
#           resolution:
#             datatype: number
#           label: plain_text_model
#       links:
#         datatype: array
#         items: [
#           {
#             datatype: map
#             attributes:
#               id: id_model
#               relation:
#                 datatype: string
#                 enum: [ 'comment' ]
#                 constraints: required
#               created: date_model
#               modified: date_model
#               creator: user_ref_model
#               body: body_model
#           }
#           {
#             datatype: map
#             attributes:
#               relation:
#                 datatype: string
#                 enum: [ 'attachment' ]
#                 constraints: required
#               uri:
#                 datatype: string
#                 format: uri
#                 constraints: required
#               created: date_model
#               modified: date_model
#               creator: user_ref_model
#           }
#         ]

console.log JSON.stringify(root,null,2)
