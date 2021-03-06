require 'mongomapper_id2'

class Helper < User
  many :helper_request, :foreign_key => :helper_id, :class_name => "HelperRequest"

  key :role, String
  
  before_create :set_role
  
  def set_role()
    self.role = "helper"
  end

  #TODO to be improved with snooze functionality
  def self.available request=nil, limit=5
    request_id = request.present? ? request.id : nil
    contacted_helpers = HelperRequest.where(:request_id => request_id).fields(:helper_id).all.collect(&:helper_id)
    Helper.where(:id.nin => contacted_helpers).all.sample(limit)
  end
end