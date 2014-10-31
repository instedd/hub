class VerboiceConnector < Connector
  include Entity

  store_accessor :settings, :url
  after_initialize :initialize_defaults, :if => :new_record?

  def properties
    {"projects" => Projects.new(self)}
  end

  def connector
    self
  end

  private

  def initialize_defaults
    self.url = "http://verboice.instedd.org" unless self.url
  end

  class Projects
    include EntitySet

    delegate :connector, to: :@parent

    def initialize(parent)
      @parent = parent
    end

    def path
      "projects"
    end

    def label
      "Projects"
    end

    def type
      {
        kind: :entity_set,
        entity_type: {
          kind: :struct,
          members: []
        }
      }
    end

    def entities
      @entities = []
    end

    def reflect_entities
      entities
    end
  end

end
