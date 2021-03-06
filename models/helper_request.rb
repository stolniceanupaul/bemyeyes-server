require 'mongomapper_id2'

class HelperRequest
  include MongoMapper::Document

  belongs_to :request, :class_name => "Request"
  belongs_to :helper, :class_name => "Helper"

  auto_increment!
  timestamps!

end