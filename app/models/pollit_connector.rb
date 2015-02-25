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
        "name" => SimpleProperty.name(label(context.user))
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


end
