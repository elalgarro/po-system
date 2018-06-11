class PurchaseOrdersController < ApplicationController
  before_filter :authenticate_user!
  before_filter :setup_variables , except: :index
  load_and_authorize_resource :project
  

  def new
    @purchase_order = PurchaseOrder.new(project_id: @project.id)
    @parent_companies = Company.parent_companies_of_type( CompanyType::PO_VENDOR )
        
    respond_to do |format|
      format.html 
      format.json { render json: @purchase_order }
    end
  end

  def edit
    @purchase_order = PurchaseOrder.find(params[:id])
    @company = Company.includes(vendor_products: {supply_type: [:po_type, :units]}).find( @purchase_order.vendor_company_id )
    @vendor_products = VendorProduct.includes(supply_type: [:po_type, :units]).where( company_id: @company.id ).sort_by{ |v| [v.supply_type.po_type.name, v.supply_type.name ] }
    
    @vendor_products.each do |vp|
      existing_po_item = @purchase_order.po_items.select{|po| po.supply_type_id == vp.supply_type_id }
      unless existing_po_item.count > 0
        @purchase_order.po_items.build(supply_type_id: vp.supply_type_id, po_type_id: vp.supply_type.po_type_id, unit_id: vp.supply_type.units.first.id, unit_price: vp.whole_sale_price )
      end
    end
  end

  def create
    respond_to do |format|
      if @purchase_order.save
        format.html { redirect_to project_purchase_order_path(@project,@purchase_order), notice: 'Purchase order was successfully created.' }
        format.json { render json: @purchase_order, status: :created, location: @purchase_order }
      else
        format.html { render action: "new" }
        format.json { render json: @purchase_order.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @purchase_order = PurchaseOrder.find(params[:id])
        
    respond_to do |format|
      if @purchase_order.update_attributes(permitted_params.purchase_order)
        format.html { redirect_to project_purchase_order_path(@project, @purchase_order), notice: 'Purchase order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @purchase_order.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @purchase_order = PurchaseOrder.find(params[:id])
    @purchase_order.destroy

    respond_to do |format|
      format.html { redirect_to project_purchase_orders_url }
      format.json { head :no_content }
    end
  end
  
  def update_select
    @companies = Company.includes(:physical_address).where( parent_id: params[:company_id] )
    if @companies.blank?
      @companies = Company.includes(:physical_address).where( id: params[:company_id] )
    end
    render layout:false 
  end
  
  def update_price
    @vendor_supply_price = VendorProduct.where(supply_type_id: params[:supply_type_id], company_id: params[:company_id]).first
    render layout:false 
  end
  
  def po_item_row
    @purchase_order  = params[:id].blank? ? PurchaseOrder.new() : PurchaseOrder.find(params[:id])
    @purchase_order.vendor_company_id = params[:company_id]
    @company = Company.includes(vendor_products: {supply_type: [:po_type, :units]}).find(params[:company_id])
    @vendor_products = VendorProduct.includes(supply_type: [:po_type, :units]).where( company_id: @company.id )
    po_types = @vendor_products.collect{ |vp| vp.supply_type.po_type }.uniq
    render partial: 'po_items', locals: {index:params[:index], po_types: po_types}
  end
  
  def update_unit_display
    @record = SupplyType.find(params[:supply_type_id]).units.first
    render layout:false
  end
  
  def po_items
    @purchase_order = params[:id].blank? ? PurchaseOrder.new() : PurchaseOrder.find(params[:id])
    @purchase_order.vendor_company_id = params[:company_id]

    3.times{@purchase_order.po_items.build}
    render partial: "po_items", layout: false
  end
  
  def rental_rates
    rates = EquipmentRate.for(Company.rental_company.id, params[:equipment_name_id])    
    json = {}
    rates.each{ |r| json[r.unit] = number_to_currency(r.rate, unit: "")}
    render json: json
  end

private

PROJECT_AND_VENDOR_ASSOCIATIONS = [:po_items, :po_types, :supply_types, :gl_codes, :vendor_products, :codes, :vendor]

def setup_variables
  @project = Project.includes(:jobsite_addresses).find(params[:project_id]) unless params[:project_id].blank?
  
  if params[:id].present?
    @purchase_order = PurchaseOrder.find( params[:id])
  else
    @purchase_order =  PurchaseOrder.new( permitted_params.purchase_order )
  end
  
  if @purchase_order.blank?
    flash[:warning] = "No Purchase Order ID given."
    path = "/projects/#{@project.id}/purchase_orders"
    redirect_to path
  end
  @company = Company.account_company
end
  
end

