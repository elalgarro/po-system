class PurchaseOrder < ActiveRecord::Base
  audited allow_mass_assignment: true
  
  belongs_to :vendor, class_name: 'Company', foreign_key: "vendor_company_id"
  belongs_to :vendor_location, class_name: 'Company', foreign_key: "vendor_location_id"
  belongs_to :requested_by_user, class_name: 'User', foreign_key: "requested_by_user_id"
  belongs_to :verbally_approved_by_user, class_name: 'User', foreign_key: "verbal_approve_user_id"
  belongs_to :signed_off_by_user, class_name: 'User', foreign_key: "signed_off_user_id"      
  # belongs_to :bid
  
  has_many :po_items
  has_many :po_types, through: :po_items, uniq: true
  has_many :supply_types, through: :po_items, uniq: true
  has_many :gl_codes, through: :supply_types, uniq: true
  has_many :vendor_products, through: :supply_types, uniq: true
  has_many :codes, through: :supply_types
  
  has_many :po_items_price_quantity, select: [:purchase_order_id, :unit_price, :quantity], class_name: "PoItem", foreign_key: "purchase_order_id"
  
  belongs_to :project 
  belongs_to :shipping_address, class_name: 'Address', foreign_key: "shipping_address_id"      
  
  belongs_to :signed_off_signature, class_name: 'Signature', foreign_key: "signed_off_signature_id"
  belongs_to :requested_by_signature, class_name: 'Signature', foreign_key: "requested_by_signature_id"
  
  accepts_nested_attributes_for :po_items, reject_if: lambda { |i| i[:quantity].blank? || i[:quantity].to_i < 0 }, allow_destroy: true

  accepts_nested_attributes_for :signed_off_signature, reject_if: lambda { |i| i[:signature_json].blank? }, allow_destroy: true
  accepts_nested_attributes_for :requested_by_signature, reject_if: lambda { |i| i[:signature_json].blank? }, allow_destroy: true

  acts_as_paranoid  
  
  after_initialize :setup_po
  
  
  
  PICKUP_SHIPPING_ID = 0
  
  def self.pos_for_project project
    includes(:po_items_price_quantity, :vendor).where(project_id: project.id)
  end
  
  def title
    "Field Purchase Order"
  end
  
  def total
    total = 0 
    po_items.each do |item|
      total += item.total if item.total
    end
    total
  end
  
  def self.next_doc_number project_id
    po = PurchaseOrder.where( project_id: project_id).order("po_number DESC").first
    po.blank? ? 1 : (po.po_number + 1)    
  end
  
  def number
    po_number.present? ? po_number.to_s.rjust(3,'0') : 'missing number'
  end
  
  def long_number
    "#{project.number}-#{number}"
  end
  
  # def supplies
  #   bid.po_items.collect{|po| po.supply}
  # end
    
  def shipping_options
    options = []
    options << ["Pick Up", PICKUP_SHIPPING_ID]
    options << ["Jobsite", project.jobsite_addresses.first.id ] unless project.jobsite_addresses.blank?
    options << ["AIE Shop", Company.find(Company::AIE).physical_address.id ] 
    options
  end
  
  def po_items_total
    po_items_price_quantity.inject( 0 ){ |total, i| total += i.unit_price * i.quantity }
  end
  
  def shipping_label
    opt = shipping_options.select{|o| o[1] == shipping_address_id }
    opt.blank? ? "" : opt[0][0]
  end
  
  def po_type_options
    vendor && vendor.po_types || []
  end
  
  def po_supply_options
    v = vendor
    
    if v
      supply_types = v.supply_types
      po_types = supply_types.collect{|st| st.po_type }.uniq
      if po_types.present?
        po_types
      else
        v.po_types
      end
    else
      []
    end
  end
  
private

  def setup_po
    if self.po_number.blank?
      self.po_number = PurchaseOrder.next_doc_number project_id
    end
    
    if po_date.blank?
      self.po_date = Time.zone.now.to_date
    end
  end
end
