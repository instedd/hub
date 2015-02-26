class PollitConnector < Connector

  include Entity

  store_accessor :settings, :url, :username, :password
  after_initialize :initialize_defaults, :if => :new_record?

  def properties(context)
    {"polls" => Polls.new(self)}
  end

  def has_notifiable_events?
    true
  end

  private

  def initialize_defaults
    self.url = "http://pollit.instedd.org" unless self.url
  end

  class Polls
    include EntitySet

    def initialize(parent)
      @parent = parent
    end

    def path
      "polls"
    end

    def label
      "Polls"
    end

    def query(filters, context, options)
      { items: polls(context.user).map{|poll| entity(poll)} }
    end

    def find_entity(id, context)
      Poll.new(self, id, nil, context.user)
    end

    def entity(poll)
      Poll.new(self, poll["id"], poll["title"])
    end

    def polls(user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/polls.json")
    end

    def poll(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/polls/#{id}.json")
    end

  end

  class Poll
    include Entity

    attr_reader :parent, :id, :user

    def initialize(parent, id, label = nil, user = nil)
      @parent = parent
      @id = id
      @label = label
      @user = user
    end

    def sub_path
      id
    end

    def label(user=nil)
      @label ||= poll(user || self.user)["title"]
    end

    def properties(context)
      {
        "id" => SimpleProperty.id(@id),
        "name" => SimpleProperty.name(label(context.user)),
        "questions" => Questions.new(self),
        "respondents" => Respondents.new(self),
        "answers" => Answers.new(self),
      }
    end

    def events
      { "new_answer" => NewAnswerEvent.new(self) }
    end

    def poll(user)
      @poll ||= parent.poll(id, user)
    end
  end


  class NewAnswerEvent
    include Event

    def initialize(parent)
      @parent = parent
    end

    def label
      "New answer"
    end

    def sub_path
      "new_answer"
    end

    def args(context)
      {
        id:               { type: :integer,  label: "Id" },
        poll_id:          { type: :integer,  label: "Poll Id" },
        poll_title:       { type: :string,   label: "Poll name" },
        question_id:      { type: :integer,  label: "Question Id" },
        question_title:   { type: :string,   label: "Question name" },
        respondent_phone: { type: :string,   label: "Respondent phone" },
        occurrence:       { type: :datetime, label: "Answer occurrence" },
        timestamp:        { type: :datetime, label: "Timestamp" },
        response:         { type: :string,   label: "Response" }
      }
    end

  end


  class PollEntitySet
    include EntitySet

    abstract def properties_for(attrs); end

    def initialize(parent)
      @parent = parent
    end

    def path
      @path ||= "#{@parent.path}/#{self.class.name.split('::').last.underscore}"
    end

    def reflect_entities(context)
    end

    def entity_properties(context)
      @properties ||= properties_for({})
    end

    def label
      self.class.name.split('::').last.humanize.titleize
    end

    def entity_class
      self.class.name.singularize.constantize
    end

    def query(filters, context, options)
      { items: entities(context.user, filters).map{|item| entity_class.new(self, item)} }
    end

    def find_entity(id, context)
      entity_class.new(self, entity(id, context))
    end

    def entities(user, filters={})
      url =  "#{connector.url}/api/#{path}.json"
      url << "?#{filters.to_query}" unless filters.empty?
      GuissoRestClient.new(connector, user).get(url)
    end

    def entity(id, user)
      GuissoRestClient.new(connector, user).get("#{connector.url}/api/#{path}/#{id}.json")
    end
  end

  class PollEntity
    include Entity

    attr_reader :id

    abstract def label; end

    def initialize(parent, attrs)
      @parent = parent
      @attrs = attrs
      @id = attrs['id']
    end

    def sub_path
      id
    end

    def properties(context)
      @parent.properties_for(@attrs)
    end
  end


  class Questions < PollEntitySet
    def properties_for(attrs)
      {
        id: SimpleProperty.id(attrs["id"]),
        title: SimpleProperty.string("Title", attrs['title']),
        description: SimpleProperty.string("Description", attrs['description']),
        kind: SimpleProperty.string("Kind", attrs['kind']),
        numeric_max: SimpleProperty.integer("Max", attrs['numeric_max']),
        numeric_min: SimpleProperty.integer("Min", attrs['numeric_min']),
        options: SimpleProperty.string("Options", attrs['options'].try(:join, ','))
      }
    end

  end

  class Question < PollEntity
    def label
      @attrs['title']
    end
  end


  class Respondents < PollEntitySet
     def properties_for(attrs)
      {
        id: SimpleProperty.id(attrs["id"]),
        phone: SimpleProperty.string("Phone", attrs['phone']),
        confirmed: SimpleProperty.boolean("Confirmed", attrs['confirmed'])
      }
    end
  end

  class Respondent < PollEntity
    def label
      @attrs['phone']
    end
  end


  class Answers < PollEntitySet
    def properties_for(attrs)
      {
        id:               SimpleProperty.id(attrs["id"]),
        question_id:      SimpleProperty.integer("Question Id", attrs['question_id']),
        question_title:   SimpleProperty.string("Question name", attrs['question_title']),
        respondent_phone: SimpleProperty.string("Respondent phone", attrs['respondent_phone']),
        occurrence:       SimpleProperty.datetime("Answer occurrence", attrs['occurrence']),
        timestamp:        SimpleProperty.datetime("Timestamp", attrs['timestamp']),
        response:         SimpleProperty.string("Response", attrs['response'])
      }
    end
  end

  class Answer < PollEntity
    def label
      @attrs['response']
    end
  end

end
