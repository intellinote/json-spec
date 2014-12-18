matching = (regex)->
  {'matching':regex.toString()}

not_matching = (regex)->
  {'not-matching':regex.toString()}

unique = 'unique'
required = 'required'

string = 'string'
map = 'map'
number = 'number'
array = 'array'

multiline = 'multiline'
singleline = not_matching "\\t|\\f|\\n|\\v|\\r"
iso8601date = matching "^((\\d{4})-(\\d{2})-(\\d{2}))T((\\d{2})\\:(\\d{2})\\:((\\d{2})(?:\\.(\\d{3}))?)((?:[A-Z]+)|(?:[+-]\\d{2}\\:\\d{2})))$"
uri = 'uri'
email = 'email'

################################################################################

id_model = {
  description: "A locally unique identifier."
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
}

creator_model = {
  description: "Identifier for the user that created this object."
  datatype: map
  attributes:
    "user-id":
      datatype: string
      constraints: [ required ] # TODO cross-ref requirement
      format: singleline
}

created_date_model =
  description: "The date this object was first created."
  datatype: string
  format: iso8601date

modified_date_model =
  description: "The date this object was last updated."
  datatype: string
  format: iso8601date

body_model =
  description: "Map containing the body of the note, keyed by content-type.  Typically one of `text/html` or `text/plain` will appear in this map, but not both."
  datatype: map
  attributes:
    "text/html":
      datatype: string
      description: "Body of note. HTML markup is allowed."
    "text/plain":
      datatype: string
      description: "Body of note as plain text (no markup)."

note_model =
  description: "A note or task."
  datatype: map
  attributes:
    type:
      description: "Identifies the type of note."
      datatype: string
      enum: ['task','note']
      default: 'note'
    id: id_model
    title:
      description: "Title of note. Markup is not allowed."
      datatype: string
      format: singleline
    body: body_model
    tags:
      description: "List of tags associated with this note."
      datatype: array
      items:
        description: "A tag, represented as a plain-text string."
        datatype: string
        format: singleline
    created: created_date_model
    modified: modified_date_model
    creator: creator_model
    location:
      description: "A geographical location associated with this note."
      datatype: map
      attributes:
        latitude:
          description: "Latitude coordinate for this location, in degrees. Optional, but *should* be provided whenever a `longitude` value appears"
          datatype: number
          range: [-90,90]
        longitude:
          description: "Longitude coordinate for this location, in degrees. Optional, but *should* be provided whenever a `latitude` value appears"
          datatype: number
          range: [-90,90]
        elevation:
          description: "Elevation for this location, in meters above sea-level."
          datatype: number
        resolution:
          description: "Approximate minimum accuracy of location data, when known, in meters."
          datatype: number
        label:
          description: "A human-readable label or description for this location; possibly user-supplied. Markup is not allowed."
          datatype: string
          format: singleline
    links:
      description: "List of objects related to this note, such as comments or external files."
      datatype: array
      items: [
        {
          description: "A comment, which is essentially a nested note"
          datatype: map
          attributes:
            id: id_model
            relation:
              description: "Identifies the relationship between this object and the parent note, in this case, `comment`."
              datatype: string
              enum: [ 'comment' ]
              constraints: required
            created: created_date_model
            modified: modified_date_model
            creator: creator_model
            body: body_model
            links:
              datatype: array
              description: "A nested list of objects associated with this comment. The format is identical to the `note.links` attribute."
        }
        {
          description: "An attachment such as an external file."
          datatype: map
          attributes:
            filename:
              description: "The original name of the attached file."
              datatype: string
              format: singleline
            "mime-type":
              description: "The MIME Type of the associated data."
              datatype: string
              format:  [matching("^.+\\/.+$"), singleline]
            title:
              description: "Plain-text human-readable name for this attachment."
              datatype: string
              format: singleline
            relation:
              description: "Identifies the relationship between this object and the parent note, in this case, `attachment`."
              datatype: string
              enum: [ 'attachment' ]
              constraints: required
            uri:
              description: "Contents of or reference to contents of this attachment. For stand-alone files, a `data` URI is STRONGLY preferred, but in other cases a `file`, `http` or `https` URL may be more appropriate."
              datatype: string
              format: uri
              constraints: required
            created: created_date_model
            modified: modified_date_model
            creator: creator_model
        }
      ]

person_vcard_model =
  description: "A person represented by vCard data."
  datatype: map
  attributes:
    vcard:
      description: "A string containing a valid vCard representation of this person."
      datatype: string

person_fielded_model =
  description: "A person represented by fielded data."
  datatype: map
  attributes:
    name:
      description: "Container for the person's name."
      datatype: map
      attributes:
        given:
          description: "Person's first name, as a plain-text string."
          datatype: string
          constraints: required
          format: singleline
        family:
          description: "Person's last name, as a plain-text string."
          datatype: string
          constraints: required
          format: singleline
    email:
      description: "A *list* of email addresses for this person.  The first element in the list is assumed to be the primary address."
      datatype: array
      items:
        description: "String containing a single email address."
        datatype: string
        format: email
    tel:
      description: "A list of phone numbers for this person.  Multiple numbers of each type are allowed. The first element of each type is assumed to be primary."
      datatype: array
      items:
        [
          {
            datatype: map
            attributes:
              work:
                description: "Work phone number."
                datatype: string
                format: singleline
          }
          {
            datatype: map
            attributes:
              cell:
                description: "Mobile phone number."
                datatype: string
                format: singleline
          }
          {
            datatype: map
            attributes:
              home:
                description: "Home phone number."
                datatype: string
                format: singleline
          }
          {
            datatype: map
            attributes:
              fax:
                description: "Fax number."
                datatype: string
                format: singleline
          }
        ]

person_model = [ person_vcard_model, person_fielded_model ]

root =
  description: "Root of Intellinote's import format."
  datatype: map
  attributes:
    "meta-data":
      description: "Meta-data about this document."
      datatype: map
      constraints: required
      attributes:
        version:
          description: "The version of this specification that the data file follows, in *semver* format.  The current version is `1.0.0`."
          datatype: string
          constraints: required
          format:  matching "^[0-9]+\.[0-9]+\.[0-9]+$"
        generated:
          description: "The date this data file was generated, as an ISO-8601 format string."
          datatype: string
          format: iso8601date
        generator:
          description: "Identifier for the program or system that created this data file."
          datatype: string
          format: singleline
        source:
          description: "Identifier for the original source system of the data in this data file."
          datatype: string
          format: singleline
    workspaces:
      description: "A list of *workspace* objects."
      datatype: array
      items:
        description: "A *workspace* containing zero or more *notes* and *people*."
        datatype: map
        attributes:
          id: id_model
          name:
            description: "A human-readable label for this workspace."
            datatype: string
            format: singleline
            constraints: required
          description:
            description: "A brief, human-readable, plain-text description of this workspace."
            datatype: string
            format: multiline
          created: created_date_model
          modified: modified_date_model
          creator: creator_model
          notes:
            description:"A list of *note* objects. Each *note* represents a note or task in the *workspace*."
            datatype: array
            items: note_model
          people:
            description:"A map of people associated with or referenced within this workspace, keyed by user identifier. The keys to this map are `user_id` values (as referenced elsewhere in this document)."
            datatype: map
            attributes:
              '*': person_model


console.log JSON.stringify(root,null,2)
