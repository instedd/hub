module SharedContext
  extend RSpec::SharedContext
  let(:context) { RequestContext.new(user, self) }
  let(:params) { {id: 1} }
end
