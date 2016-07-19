require 'will_paginate/array'
require 'net/http'
require 'uri'
# require 'google/api_client'
# require 'google/api_client/client_secrets'
# require 'google/api_client/auth/installed_app'
# require 'gmail'
class ContactsController < ApplicationController

# /****************************************************************************************
#WakeupSales Community Edition is a web based CRM developed by WakeupSales. Copyright (C) 2015-2016

#This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 as published by the Free Software Foundation with the addition of the following permission added to Section 15 as permitted in Section 7(a): FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY SUGARCRM, SUGARCRM DISCLAIMS THE WARRANTY OF NON INFRINGEMENT OF THIRD PARTY RIGHTS.

#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

#You should have received a copy of the GNU General Public License along with this program; if not, see http://www.gnu.org/licenses or write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#You can contact WakeupSales, 2059 Camden Ave. #118, San Jose, CA - 95124, US.  or at email address support@wakeupsales.org.

#The interactive user interfaces in modified source and object code versions of this program must display Appropriate Legal Notices, as required under Section 5 of the GNU General Public License version 3.

#In accordance with Section 7(b) of the GNU General Public License version 3, these Appropriate Legal Notices must retain the display of the "Powered by WakeupSales" logo. If the display of the logo is not reasonably feasible for technical reasons, the Appropriate Legal Notices must display the words "Powered by WakeupSales".

#*****************************************************************************************/

  include ContactsHelper
  
  def index    
    #if Contact.where(:organization_id => current_user.organization.id).any?
    #  #@users = current_user.organization.contacts.group_by{|u| u.first_name[0]} 
    #  @users = Contact.where(:organization_id => current_user.organization.id).order("name,first_name")
    #end   
    # Contact.all.each do |contact|
     # contact.update_column :created_by, current_user.id
    # end 
    begin
     lastcontact = current_user.activities.where("activity_status=? and activity_type in (?)","Create",["IndividualContact","CompanyContact"]).last
     unless lastcontact.present?
       lastcontact = current_user.organization.activities.where("activity_status=? and activity_type in (?)","Create",["IndividualContact","CompanyContact"]).last
      
     end
     if lastcontact.present?
       if lastcontact && lastcontact.activity_type == "IndividualContact"
         @contact = IndividualContact.find(lastcontact.activity_id)
         get_contact_attrs
       elsif lastcontact && lastcontact.activity_type == "CompanyContact"
         @contact = CompanyContact.find(lastcontact.activity_id)
         get_contact_attrs
       end
     else
        contacts=current_user.organization.individual_contacts
        @contact = contacts.last
         get_contact_attrs
     end
    rescue ActiveRecord::RecordNotFound
     flash[:alert]="It seems you don't have sufficient privilege to access this item or something went wrong with your account permissions.<br/> Please contact Admin to get this fixed."
    #redirect_to contacts_path
    end
    respond_to do |format|    
      format.html #{ redirect_to contacts_url }
      format.json { head :no_content }
    end
  end
  
  
  def new
  end


  def create
    if params[:contact_type] == "company"
#  	  @comp = CompanyContact.where("email =?",params[:company_email]).first
      cc = CompanyContact.new
      cc.organization = current_user.organization
      cc.name = params[:company_name]
      cc.email = params[:company_email]
      cc.company_strength_id = params[:company_strength]
      cc.website = params[:website]
      cc.created_by = current_user.id
	    cc.work_phone = params[:work_phone]
	    cc.country = params[:country]

      if cc.save
        Activity.create(:organization_id => cc.organization_id,	:activity_user_id => cc.created_by,:activity_type=> "CompanyContact", :activity_id => cc.id, :activity_status => "Create",:activity_desc=>cc.name,:activity_date => Time.zone.now, :is_public => true)
        contact = cc
        save_contact_to_address(contact,params[:country]) if params[:country].present?
        save_contact_to_phone contact,params[:work_phone], params[:extension_contact_popup],"work" if params[:work_phone].present?
        msg = (params[:is_edit_contact] == "true" ? "#{contact.id}" : "index") 
      else
        alert_msg = ""
        msgs=cc.errors.messages
        msgs.keys.each_with_index do |m,i|
          alert_msg=m.to_s.camelcase+" "+msgs[m].first
          alert_msg += "<br />" if i > 0
        end
	      msg=alert_msg
      end
      
    elsif params[:contact_type] == "individual"
  	    ic=IndividualContact.new
  	    ic.organization_id = current_user.organization_id
  	    ic.first_name = params[:first_name]
  	    ic.email = params[:email]
  	    ic.position = params[:position]
  	    ic.work_phone = params[:work_phone]
  	    ic.country = params[:country]
  	    ic.created_by = current_user.id
  	    
        if params[:company_id].present?
          ic.company_contact_id = params[:company_id]
        end
    	  if ic.save
          Activity.create(:organization_id => ic.organization_id,	:activity_user_id => ic.created_by,:activity_type=> "IndividualContact", :activity_id => ic.id, :activity_status => "Create",:activity_desc=>ic.first_name,:activity_date => Time.zone.now, :is_public => true)
    	    if !params[:company_id].present? && params[:company_value].present?
    	      cc=CompanyContact.new
    	      cc.organization = current_user.organization
    	      cc.name = params[:company_value]
    	      cc.country = params[:country]
    	      cc.work_phone = params[:work_phone]
    	      cc.extension = params[:extension_contact_popup]
    	      cc.created_by = current_user.id
            if cc.save
              ic.update_column(:company_contact_id, cc.id)
#              save_contact_to_address(cc,params[:country]) if params[:country].present?
#              save_contact_to_phone cc,params[:work_phone], params[:extension_contact_popup],"work" if params[:work_phone].present?
            end
          end
            #save_contact_to_address(ic,params[:country]) if params[:country].present?
            #save_contact_to_phone ic,params[:work_phone], params[:extension_contact_popup],"work" if params[:work_phone].present?
    	      msg = (params[:is_edit_contact] == "true" ? "#{ic.id}" : "index") 
            
    	 else
          alert_msg = ""
          msgs=ic.errors.messages
          msgs.keys.each_with_index do |m,i|
            alert_msg=m.to_s.camelcase+" "+msgs[m].first
            alert_msg += "<br />" if i > 0
          end
  	      msg=alert_msg
    	 end
    end
    render :text => msg
  end
 
  def get_contact_ajax
   if params[:contact_type] == "individual_contact"
     contacts=current_user.organization.individual_contacts

     @contact = contacts.find(params[:id])
     get_contact_attrs



   else
     contacts=current_user.organization.company_contacts
      @contact = contacts.find(params[:id])
     get_contact_attrs
   end
   render :partial => "show"
 end
 
  def individual_contact_detail
   contacts=current_user.organization.individual_contacts
	begin
     @contact = contacts.find(params[:id])
     get_contact_attrs
	  rescue ActiveRecord::RecordNotFound
		 flash[:alert]="It seems you don't have sufficient privilege to access this item or something went wrong with your account permissions.<br/> Please contact Admin to get this fixed."
		redirect_to contacts_path
	  end
  end
  
  
  def company_contact_detail
   contacts=current_user.organization.company_contacts
	begin

     @contact = contacts.find(params[:id])
     get_contact_attrs
	  rescue ActiveRecord::RecordNotFound
		 flash[:alert]="It seems you don't have sufficient privilege to access this item or something went wrong with your account permissions.<br/> Please contact Admin to get this fixed."
		redirect_to contacts_path
	  end
  end
  
  def get_contact_attrs
     @work_phone =  @contact.present? && @contact.phones.present? ? (@contact.phones.by_phone_type("work")) : ''
     @mobile_phone = @contact.present? && @contact.phones.present? ? (@contact.phones.by_phone_type("mobile")) : ''
     @deals= 0 #@contact.deals.count
     @today_tasks=Task.task_list(nil,"today",@contact, 10) if @contact.present?
     @overdue_tasks=Task.task_list(nil,"overdue",@contact, 10) if @contact.present?
     @upcoming_tasks=Task.task_list(nil,"upcoming",@contact, 10) if @contact.present?
     @completed_tasks=Task.task_list(nil,"all",@contact, 10).where("is_completed=? AND DATE_FORMAT(due_date, '%Y/%m/%d') <> ? ", true, Time.now.strftime("%Y/%m/%d"))


  end

 def edit_company_contact
   session[:prev_page] = nil
#   @contact = IndividualContact.find 1
   @contact = CompanyContact.find params[:id]
   session[:prev_page] = request.referer
#   if (current_user.is_admin? || current_user.is_super_admin?) || (current_user.id == @contact.created_by)
     @work_phone = @contact.phones.by_phone_type "work"
     @mobile_phone = @contact.phones.by_phone_type "mobile"     
     @cat = @@category
#   else
#     flash[:notice] = "Oops!!! you are not authorized to do so."
#     redirect_to contacts_url
#   end
  end
  
  def edit_individual_contact
   session[:prev_page] = nil
   @contact = IndividualContact.find params[:id]
   session[:prev_page] = request.referer
#   if (current_user.is_admin? || current_user.is_super_admin?) || (current_user.id == @contact.created_by)
     @work_phone = @contact.phones.by_phone_type "work"
     @mobile_phone = @contact.phones.by_phone_type "mobile"     
     @cat = @@category
#   else
#     flash[:notice] = "Oops!!! you are not authorized to do so."
#     redirect_to contacts_url
#   end
  end
  

  def update
    if params[:company_contact].present?
      contact = CompanyContact.find params[:id]
      contact_params=params[:company_contact]
       # if (params[:company_contact][:linkedin_url].present?)
         # social_img_url = get_image_url params[:company_contact][:linkedin_url]
         # if social_img_url != "not_found"
          # contact.contact_image = URI.parse(social_img_url)
         # end
      # end
    elsif params[:individual_contact].present?
      contact = IndividualContact.find params[:id]
      params[:individual_contact][:company_contact_id]=params[:company_id] if params[:company_id].present?
      # if (params[:individual_contact][:linkedin_url].present?)
         # social_img_url = get_image_url params[:individual_contact][:linkedin_url]
         # if social_img_url != "not_found"
          # contact.contact_image = URI.parse(social_img_url)
         # end
      # end
      contact_params=params[:individual_contact]
    end
    
    if contact.update_attributes contact_params
      if params[:individual_contact].present? && !params[:company_id].present? && params[:individual_contact][:name].present?
    	      cc=CompanyContact.new
    	      cc.organization = current_user.organization
    	      cc.name = params[:individual_contact][:name]
    	      cc.country = params[:individual_contact][:country]
    	      cc.work_phone = params[:individual_contact][:work_phone]
    	      cc.extension = params[:individual_contact][:extension]
    	      cc.created_by = current_user.id
          if cc.save(validate: false)
            contact.update_column(:company_contact_id, cc.id)
#            save_contact_to_address(cc,params[:country]) if params[:country].present?
#            save_contact_to_phone cc,params[:work_phone], params[:extension_contact_popup],"work" if params[:work_phone].present?
          end
       end
      flash[:notice] = "Contact has been updated successfully."
      if !request.xhr?
        redirect_to session[:prev_page].nil? ? request.referer : session[:prev_page]
        session[:prev_page] = nil
      else
        contact_info={status: false, msg: "Contact has been updated successfully.", atype: "success"}
        render :json => contact_info
      end
    else
      alert_msg=""
        msgs=contact.errors.messages
        msgs.keys.each_with_index do |m,i|
          alert_msg=m.to_s.camelcase+" "+msgs[m].first
          alert_msg += "<br />" if i > 0
        end
     flash[:warning] = "#{alert_msg}."
      #redirect_to edit_contact_path contact
      #redirect_to request.referer
      if !request.xhr?
        redirect_to request.referer
      else
        contact_info={status: false, msg: alert_msg, atype: "warning"}
        render :json => contact_info
      end      
    end
    
#   contact = Contact.find params[:id]
#   if params[:contact][:contact_type] == "Company"
#     contact.name = params[:contact][:name]
#     contact.company_strength_id = params[:contact][:company_strength]
#   end 
#   contact.contact_type = params[:contact][:contact_type]
#   contact.first_name = params[:contact][:first_name] 
#   contact.last_name = params[:contact][:last_name] 
#   contact.email = params[:contact][:email] 
#   contact.website = params[:contact][:website] 
#   contact.messanger_type = params[:contact][:messanger_type] 
#   contact.messanger_id = params[:contact][:messanger_id] 
#   contact.facebook_url = params[:contact][:facebook_url] 
#   contact.linkedin_url = params[:contact][:linkedin_url] 
#   contact.twitter_url = params[:contact][:twitter_url] 
#   contact.is_public = params[:contact][:is_public] 
#   contact.save
#   ##save address information for contact
#   if(contact.address.nil?) 
#    address = Address.create :organization => current_user.organization, :addressable => contact,:address=>params[:contact][:full_address], :country_id=>params[:contact][:country],
#         :state=>params[:contact][:state],:city=>params[:contact][:city],:zipcode=>params[:contact][:zip_code]
#   else 
#    contact.address.update_attributes(:address=>params[:contact][:full_address], :country_id=>params[:contact][:country],
#          :state=>params[:contact][:state],:city=>params[:contact][:city],:zipcode=>params[:contact][:zip_code])
#   end 
#   ##save phone numbers to phone
#   work_phone = contact.phones.by_phone_type "work"
#   mobile_phone = contact.phones.by_phone_type "mobile"
#   if (!work_phone.blank?) && (!params[:contact][:work_phone].nil? || !params[:contact][:work_phone].blank?)
#     #work_phone.first.update_column :phone_no, params[:contact][:work_phone]
#     work_phone.first.update_attributes(:phone_no=>params[:contact][:work_phone],:extension=>params[:extension_contact_edit])
#   else
#     save_contact_to_phone contact,params[:contact][:work_phone], params[:extension_contact_edit],"work"
#   end
#   if (!mobile_phone.blank?) && (!params[:contact][:mobile_number].nil? || !params[:contact][:mobile_number].blank?)
#     #mobile_phone.first.update_column :phone_no, params[:contact][:mobile_number]
#     mobile_phone.first.update_attributes(:phone_no=>params[:contact][:mobile_number],:extension=>params[:extension_contact_edit])
#   else
#     save_contact_to_phone contact,params[:contact][:work_phone], params[:extension_contact_edit],"mobile"
#   end
#   ##save image to image
#   if (contact.image.nil?) && (!params[:contact][:contact_image].nil?) 
#    image = Image.create(:organization => current_user.organization,:image=>params[:contact][:contact_image], :imagable=>contact)
#   elsif (!contact.image.nil?) && (!params[:contact][:contact_image].nil?)
#    contact.image.update_attributes(:image=>params[:contact][:contact_image])
#   end  
#   flash[:notice] = "Contact has been updated successfully."
#   redirect_to session[:prev_page].nil? ? contacts_path : session[:prev_page]
#   session[:prev_page] = nil
  end
  
  def save_contact_timezone
   if params[:pk] == "individual_contact"
    @contact = IndividualContact.find params[:name].to_i
	@contact.update_column :time_zone, params[:value]
   elsif params[:pk] == "company_contact"
     @contact = CompanyContact.find params[:name].to_i
    @contact.update_column :time_zone, params[:value]
   end
   render :text => '<div class="fl grey_act">Current Time:</div><div class="fl"><div style="float:left;font-weight:bold;color:#2A64A2">'+DateTime.parse(ActiveSupport::TimeZone[@contact.time_zone].now.to_s(:rfc822)).strftime('%a, %d %b %H:%M:%S')+'</div></div>'
  end
  def destroy
    if params[:type] == "company"
      contact = CompanyContact.find params[:id]
    elsif params[:type] == "individual"
      contact = IndividualContact.find params[:id]
    end
    if contact.present?     
      #contact.update_column :is_active, false
      contact.update_attribute :is_active, false
      msg = "Contact has been disabled successfully."
    else
      msg = "Contact not found !!!"
    end
    #unless contact.deals.any?
     #contact.destroy
     #msg = "Contact disabled successfully."
    #else   
     #contact.update_column :is_active, false
     #msg = "Contact is already associated with deals #{contact.deals.pluck(:title)}. However contact disabled successfully."
    #end
    
    respond_to do |format|
      flash[:notice]=msg
      format.html { redirect_to request.referer }
      format.json { head :no_content }
    end
  end
  
  
  def change_status
    if params[:ctype] == "CompanyContact"
      @contact = CompanyContact.find params[:id]
      name = @contact.name.present? ? @contact.name : "Contact" if  @contact.present?
    elsif params[:ctype] == "IndividualContact"
      @contact = IndividualContact.find params[:id]
      name = @contact.first_name.present? ? @contact.first_name : "Contact" if  @contact.present?
    end
    if @contact.present?
      if params[:status] == "enable"       
        status = false  
        msg = "\'#{name}\' disabled successfully."
      elsif params[:status] == "disable"     
        status = true
        msg = "\'#{name}\' enabled successfully."
      end   
      @contact.update_column :is_active, status
    else
     msg = "Contact not found!!!"
    end
    flash[:notice] = msg
    #redirect_to contacts_path
	redirect_to request.referer
  end
  

   
  def get_all_contacts 
   #get_contacts
   @firstchars=[]

   if(params[:selected_tab]=="all" )
#     @firstcharsusers=(current_user.organization.contacts.select("distinct UPPER(LEFT(first_name,1)) as firstchar")).order("firstchar")
    ## disabled public deals view by normal user
    if(current_user.is_admin? || current_user.is_super_admin?)
    
      @firstcharsusers=IndividualContact.find_by_sql("select distinct UPPER(LEFT(name,1)) as firstchar from (SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{current_user.organization_id} ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{current_user.organization_id} )) contacts order by name")
     else
        @firstcharsusers=IndividualContact.find_by_sql("select distinct UPPER(LEFT(name,1)) as firstchar from (SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{current_user.organization_id} ) and ic.created_by = #{current_user.id} UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{current_user.organization_id} ) and cc.created_by = #{current_user.id} ) contacts order by name")
     end
   elsif(params[:selected_tab]=="individual" )

      ## disabled public deals view by normal user
      if(current_user.is_admin? || current_user.is_super_admin?)
        @firstcharsusers=(current_user.organization.individual_contacts.select("distinct UPPER(LEFT(first_name,1)) as firstchar")).order("firstchar")
      else
        @firstcharsusers=(current_user.organization.individual_contacts.select("distinct UPPER(LEFT(first_name,1)) as firstchar")).where("created_by = ? ",current_user.id).order("firstchar")
      end
   elsif(params[:selected_tab]=="customer" ) 
      ## disabled public deals view by normal user
      if(current_user.is_admin? || current_user.is_super_admin?)
        @firstcharsusers=(current_user.organization.individual_contacts.is_customer.select("distinct UPPER(LEFT(first_name,1)) as firstchar")).order("firstchar")
      else
        @firstcharsusers=(current_user.organization.individual_contacts.is_customer.select("distinct UPPER(LEFT(first_name,1)) as firstchar")).where("created_by = ? ",current_user.id).order("firstchar")
      end
   elsif(params[:selected_tab]=="mycontact" )     
      @firstcharsusers=IndividualContact.find_by_sql("select distinct UPPER(LEFT(name,1)) as firstchar from (SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{current_user.organization_id}  and ic.created_by = #{current_user.id}) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{current_user.organization_id}  and cc.created_by = #{current_user.id} )) contacts order by name")
   else
      ## disabled public deals view by normal user
      if(current_user.is_admin? || current_user.is_super_admin?)
        @firstcharsusers=(current_user.organization.company_contacts.select("distinct UPPER(LEFT(name,1)) as firstchar")).order("firstchar")
      else
        @firstcharsusers=(current_user.organization.company_contacts.select("distinct UPPER(LEFT(name,1)) as firstchar")).where("created_by = ? ",current_user.id).order("firstchar")
      end
   end
   @firstcharsusers.each do |a|
     @firstchars << a["firstchar"]
   end
   @firstchars=@firstchars.join(",")
   #@users = @users.limit(10)
   
   render :partial => "contact_list"
  end
  
  def get_more_contacts
    get_contacts
    respond_to do |format|
      format.json { render :json => contact_data(@users,params[:selected_tab])}
    end
  end
  
  
  def contact_data(contacts,selected_tab="company")
  
      contacts.map do |contact|
      #company_contact=current_user.organization.company_contacts.select("company_contacts.*, 'CompanyContact' contact_type").where("id=?", contact.id).first if contact.contact_type == "CompanyContact"
      #contact = company_contact if company_contact.present?
      [
      contact.id,
      contact.is_active?,
      contact.contact_type.sub("Contact",""),
      !contact.image.nil? ? contact.image.image.url(:icon) : "",
#      (contact.is_individual? ? (contact.first_name.present? ? contact.first_name : "") : (contact.name.present? ? contact.name : "")),
      (contact.contact_type == "CompanyContact" ? (contact.name.present? ? contact.name.strip : "") : ""),
      (contact.contact_type == "IndividualContact" ? (contact.first_name.present? ? contact.first_name.strip : "") : ""),
      contact.contact_name.strip,
      contact.phones.count > 0  && !contact.phones.first.extension.nil? ? contact.phones.first.extension : (contact.address && contact.address.country ? contact.address.country.isd_code : "")  ,
      (!contact.phones.blank? ? contact.phones.first.phone_no : "" ),
      (contact.email.present? ? contact.email : ""),
      contact.address && contact.address.country ? contact.address.country.name : "",
      false,
      (current_user.is_admin? || current_user.is_super_admin?) || (current_user.id == contact.created_by),
      ((selected_tab == 'all' || selected_tab == 'individual' || selected_tab == 'mycontact') ? (contact.full_name.present? ? contact.full_name[0] : "") : (contact.name.present? ? contact.name[0] : "")),
      contact.address && contact.address.country ? contact.address.country.id : "",
      contact.address && contact.address.state ? contact.address.state : "",
      contact.address && contact.address.city ? contact.address.city : "",
      contact.contact_type == "CompanyContact" ? "company_contact" : "individual_contact" ,
      contact.contact_type,
      contact.contact_type == "CompanyContact" ? "#{contact.id}?type=company" : "#{contact.id}?type=individual" ,
      contact.contact_status 
      ]
     end
     
  end
  
  def get_contacts
    page = !params[:page].nil? ? params[:page] : 1
    perpage = 10
    sql = ""
    letter = params[:letter]
    if IndividualContact.where(:organization_id => current_user.organization.id).first.present? || CompanyContact.where(:organization_id => current_user.organization.id).first.present?
      if params[:selected_tab] == "all" 
        if current_user.is_admin?
          if(!letter.nil? && letter.length == 1 && letter != "-")
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name LIKE '#{letter}%') UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}) and name LIKE '#{letter}%' order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name LIKE '#{letter}%'  and ic.created_by = #{@current_user.id}) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}  and cc.created_by = #{@current_user.id}) and name LIKE '#{letter}%' order by name"
            end
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name REGEXP '^[^A-Za-z]') UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}) and  name REGEXP '^[^A-Za-z]' order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name REGEXP '^[^A-Za-z]' and ic.created_by = #{@current_user.id}) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}) and  name REGEXP '^[^A-Za-z]' and cc.created_by = #{@current_user.id} order by name"
            end
          else
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} ) order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id}  and ic.created_by = #{@current_user.id}) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} ) and cc.created_by = #{@current_user.id} order by name"
            end
          end
        else
          if(!letter.nil? && letter.length == 1 && letter != "-")
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} ))  and first_name LIKE '#{letter}%' ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} )) ) and name LIKE '#{letter}%' order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND ( ( created_by=#{@current_user.id} ))  and first_name LIKE '#{letter}%' ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND ( (created_by=#{@current_user.id} )) ) and name LIKE '#{letter}%' order by name"
            end
            
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} )) and first_name REGEXP '^[^A-Za-z]') UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} )) ) and name REGEXP '^[^A-Za-z]' order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND ((created_by=#{@current_user.id} )) and first_name REGEXP '^[^A-Za-z]') UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND ((cc.created_by=#{@current_user.id} )) ) and name REGEXP '^[^A-Za-z]' order by name"
            end
          else
            ## disabled public deals view by normal user
            if(current_user.is_admin? || current_user.is_super_admin?)
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} )) ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND (is_public = true or (is_public = false and created_by=#{@current_user.id} )) )  order by name"
            else
              sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} AND ( (created_by=#{@current_user.id} )) ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id} AND ((created_by=#{@current_user.id} )) )  order by name"
            end
          end
          
        end
        @users = []
        @contacts=CompanyContact.paginate_by_sql(sql,:page => page, :per_page => perpage)
        @users = ( @contacts.map{|a| a.contact_type == 'IndividualContact' ? a.becomes(IndividualContact) : a }).flatten
        ActiveRecord::Associations::Preloader.new(@users,[:image,{:address=>:country},:phones]).run
        @type = "all"
      elsif params[:selected_tab] == "company"
#      if params[:selected_tab] == "company"
        if current_user.is_admin?
          if params[:seach_txt].present?
            if(!letter.nil? && letter.length == 1 && letter != "-")
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).by_visibilty(@current_user.organization.id,@current_user.id).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            elsif(!letter.nil? && letter.length == 1 && letter == "-")
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
              @users = CompanyContact.by_organization_id(@current_user.organization.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).by_visibilty(@current_user.organization.id,@current_user.id).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            else
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_organization_id(@current_user.organization.id).select("company_contacts.*, 'CompanyContact' contact_type").order("name").search_by(params[:seach_txt]).by_visibilty(@current_user.organization.id,@current_user.id).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            end
          else
            if(!letter.nil? && letter.length == 1 && letter != "-")
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else 
              @users = CompanyContact.by_organization_id(@current_user.organization.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").by_visibilty(@current_user.organization.id,@current_user.id).order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            elsif(!letter.nil? && letter.length == 1 && letter == "-")
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").by_visibilty(@current_user.organization.id,@current_user.id).order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            else
              ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_organization_id(@current_user.organization.id).select("company_contacts.*, 'CompanyContact' contact_type").by_visibilty(@current_user.organization.id,@current_user.id).order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
            end
          end
        else
          if(!letter.nil? && letter.length == 1 && letter != "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_visibilty(@current_user.organization.id,@current_user.id).by_first_letter_name(letter).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end

          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_visibilty(@current_user.organization.id,@current_user.id).by_alpha_name.select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          else
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = CompanyContact.by_organization_id(@current_user.organization.id).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = CompanyContact.by_visibilty(@current_user.organization.id,@current_user.id).select("company_contacts.*, 'CompanyContact' contact_type").order("name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          end
        end
        @type = "company"
        
        
      elsif params[:selected_tab] == "individual"
        if current_user.is_admin?
          if(!letter.nil? && letter.length == 1 && letter != "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_organization_id(@current_user.organization.id).by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname.paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_visibilty(@current_user.organization.id,@current_user.id).by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname.paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          else
             ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_visibilty(@current_user.organization.id,@current_user.id).by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
           end
        else
          if(!letter.nil? && letter.length == 1 && letter != "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          else
            ## disabled public deals view by normal user
              if(current_user.is_admin? || current_user.is_super_admin?)
                @users = IndividualContact.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              else
                @users = IndividualContact.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
              end
          end
        end
        @type = "individual"
      elsif params[:selected_tab] == "customer"
        if current_user.is_admin?
          if(!letter.nil? && letter.length == 1 && letter != "-")
            @users = IndividualContact.is_customer.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            @users = IndividualContact.is_customer.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname.paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
          else
             @users = IndividualContact.is_customer.by_organization_id(@current_user.organization.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
           end
        else
          if(!letter.nil? && letter.length == 1 && letter != "-")
            @users = IndividualContact.is_customer.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_first_letter(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            @users = IndividualContact.is_customer.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").by_alpha_firstname(letter).paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
          else
            @users = IndividualContact.is_customer.by_visibilty(@current_user.organization.id,@current_user.id).select("individual_contacts.*, 'IndividualContact' contact_type").order("first_name,last_name").paginate(:page => page, :per_page => perpage).includes(:image,{:address=>:country},:phones)
          end
        end
        @type = "customer"
      elsif params[:selected_tab] == "mycontact" 
          if(!letter.nil? && letter.length == 1 && letter != "-")
             sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name LIKE '#{letter}%' and ic.created_by = #{current_user.id} ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}  and cc.created_by = #{current_user.id}) and name LIKE '#{letter}%' order by name"
          elsif(!letter.nil? && letter.length == 1 && letter == "-")
            sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and first_name REGEXP '^[^A-Za-z]' and ic.created_by = #{current_user.id} ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}  and cc.created_by = #{current_user.id}) and  name REGEXP '^[^A-Za-z]' order by name"
          else
             sql="SELECT ic.id, ic.first_name name, ic.first_name first_name, ic.last_name last_name, ic.is_active, ic.email, 'IndividualContact' contact_type, ic.created_by FROM `individual_contacts` ic  WHERE (ic.organization_id = #{@current_user.organization_id} and ic.created_by = #{current_user.id} ) UNION ALL SELECT cc.id, cc.name name, cc.name name1, cc.name name2, cc.is_active, cc.email, 'CompanyContact' contact_type, cc.created_by FROM `company_contacts` cc  WHERE (cc.organization_id = #{@current_user.organization_id}  and cc.created_by = #{current_user.id}) order by name"
          end
        
        @users = []
        @contacts=CompanyContact.paginate_by_sql(sql,:page => page, :per_page => perpage)
        @users = ( @contacts.map{|a| a.contact_type == 'IndividualContact' ? a.becomes(IndividualContact) : a }).flatten
        ActiveRecord::Associations::Preloader.new(@users,[:image,{:address=>:country},:phones]).run
        @type = "all"
      end
      if params[:seach_txt].present?
        @users = @users.search_by(params[:seach_txt]).paginate(:page => page, :per_page => perpage)
      end
    end
  end
  
  
  def send_email
    contact_type =""
    full_name =""
    if(params[:email_contact_type] =="IndividualContact" || params[:email_contact_type] =="individual_contact")
      contact_type ="individual_contact"
      contactable_type = "IndividualContact"
      contact = IndividualContact.find params[:email_contact_id]
      full_name=contact.full_name
      contact_info = {:contact_type => contact_type,:contact_id=>contact.id, :full_name=>full_name}
    elsif(params[:email_contact_type] =="CompanyContact" || params[:email_contact_type] =="company_contact")
      contact_type ="company_contact"
      contactable_type = "CompanyContact"
      contact = CompanyContact.find params[:email_contact_id]
      full_name=contact.full_name
      contact_info = {:contact_type => contact_type,:contact_id=>contact.id, :full_name=>full_name}
    end
	mail_letter = MailLetter.create :organization_id => current_user.organization.id, :mailable_id => params[:mailer_id],:mailable_type=>params[:mailer_type],:mailto=>params[:to],:subject=>params[:subject],
	           :description=>params[:message],:mail_by=>current_user.id,:mail_cc=>params[:cc],:mail_bcc=>params[:bcc], 
	           :contact_info=> contact_info
   if !params[:attachment].nil? && !params[:attachment].blank?
     file = params[:attachment].tempfile.path
     file_name = params[:attachment].original_filename
   else
     file = ""
     file_name = ""
   end
 #if (current_user.email_notification.nil?) || (current_user.email_notification && current_user.email_notification.due_task  == true && current_user.email_notification.donot_send == false)
   Notification.send_email(params[:to],params[:cc],params[:bcc],params[:subject],params[:message],file_name,file, current_user.email ).deliver
   activity = Activity.create(:organization_id => current_user.organization.id,  :activity_user_id => current_user.id,:activity_type=> mail_letter.class.name, :activity_id => mail_letter.id, :activity_status => "Mail Sent", :activity_desc=>mail_letter.subject,:activity_date => mail_letter.updated_at, :is_public => (mail_letter.mailable.nil? || mail_letter.mailable.is_public.nil? ||  mail_letter.mailable.is_public.blank?) ? false : mail_letter.mailable.is_public, :source_id => mail_letter.mailable.id)
   ActivitiesContact.create(:organization_id => current_user.organization_id, :activity_id=> activity.id,:contactable_type=>contactable_type,:contactable_id=> params[:email_contact_id])
 #end
   flash[:notice] = "Mail sent successfully."
   redirect_to request.referrer
   #render :text => "success"
  end

  def contact_widget
    if params[:tab_type].present? && params[:id].present? && params[:contact_type].present?
      if params[:contact_type] == "CompanyContact"
        company_contact_detail
      else
        individual_contact_detail
      end
      case params[:tab_type]
      when "activity"
        partial_file="time_line_stream"
      when "deals"
        @deals=[]
        @contact.deals_contacts.order("id desc").each do |dc|
          @deals << dc.deal if dc.present?
        end
        #partial_file="deal_list"
		partial_file="users/deal_list"
      when "people"
        @people=@contact.individual_contacts
        partial_file="people_list"
      end
      render partial: partial_file
    else  
      
    end
  end
  
  def add_contact_form
    if params[:contact_type] == "company"
      partial_file = "shared/add_company_contact"
    elsif params[:contact_type] == "individual"
      partial_file = "shared/add_individual_contact"
    end
    render partial: partial_file, :content_type => 'text/html'
  end
  def contact_callback
  
    # if(!params[:page].present?)
    #for local
      #@contacts = [{:id=>"http://www.google.com/m8/feeds/contacts/krishna.sahoo%40andolasoft.com/base/9452fef8ca2457a", :first_name=>"Meera", :last_name=>"Monalisa", :name=>"Meera Monalisa", :email=>"meera.monalisa@andolasoft.co.in", :gender=>nil, :birthday=>nil, :profile_picture=>nil, :relation=>nil}, {:id=>"http://www.google.com/m8/feeds/contacts/krishna.sahoo%40andolasoft.com/base/f0cafe988576b77", :first_name=>"Rajendra", :last_name=>"Nayak", :name=>"Rajendra Nayak", :email=>"rajendra.nayak@andolasoft.co.in", :gender=>nil, :birthday=>nil, :profile_picture=>nil, :relation=>nil}]
      
      @contacts = request.env['omnicontacts.contacts']
      p "omni contactssssssssssssssssssssssss"
      #p @contacts
      puts "inside contacts controllereeeeeeeeeeeeeeeeeeeeeee"
      @contacts.each do |contact|
      p contact[:email]
      p contact[:connection_date]
        TempContact.create(domain: "gmail",
        import_by: current_user.id,
        first_name: contact[:first_name],
        last_name: contact[:last_name],
        name: contact[:name],
        email: contact[:email],
        gender: contact[:gender],
        birthday: contact[:birthday],
        profile_picture: contact[:profile_picture],
        updated: contact[:connection_date],
        relation: contact[:relation],
        address_1: contact[:address_1],
        address_2: contact[:address_2],
        city: contact[:city],
        region: contact[:region],
        country: contact[:country],
        postcode: contact[:postcode],
        phone_number: contact[:phone_number]
        )

      end
      

     respond_to do |format|
       format.html 
     end
  end
  def import_contacts
    
    emailids=params[:emailids].chomp("|").split("|")
    tempcontacts = TempContact.where("email in (?) ", emailids)
    tempcontacts.each do |tcontact|
      ic=(exist_contact=IndividualContact.where(:email => tcontact.email).first).present? ? exist_contact : IndividualContact.create(:email => tcontact.email)
      ic.update_attributes(:organization_id => current_user.organization_id, :first_name => tcontact.first_name, :last_name => tcontact.last_name, :is_public => false, :created_by => current_user.id ) if ic.present?
    end

    flash[:notice] = "Successfully imported " + (!tempcontacts.nil? ? tempcontacts.count.to_s : "0") +" contact(s)"
    tempcontacts.destroy_all
    redirect_to contacts_path
  end
  
  def import_failure
    flash[:alert] = "Unable to fetch contact due to '#{params[:error_message].humanize}'."
    redirect_to contacts_path
  end
  def testgmail
 
    # puts "coming to testgmail"
    
# # Initialize the client.
# client = Google::APIClient.new(
  # :application_name => 'Wakeupsales',
  # :application_version => '1.0.0'
  
# )
# client.authorization.clear_credentials!
# puts "11111111111111111111111111111111"
# Initialize Google+ API. Note this will make a request to the
# discovery service every time, so be sure to use serialization
# in your production code. Check the samples for more details.
# gmail = client.discovered_api('gmail')
# puts "22222222222222222222222222222"
# # Load client secrets from your client_secrets.json.
# client_secrets = Google::APIClient::ClientSecrets.load
# puts "3333333333333333333333333333333"
# # Run installed application flow. Check the samples for a more
# # complete example that saves the credentials between runs.
# flow = Google::APIClient.new(
  # :client_id=>'376013845018',
  # :client_secret =>'wH0RnhemFNxScLBXk6tu25wQ',
  # :scope => ['https://mail.google.com/','https://www.googleapis.com/auth/gmail.readonly'],
  # :redirect_uris=> ["http://localhost:3001/testgmail"],
  # :grant_type=>"refresh_token"
  
# )
# puts "flowwwwwwwwwwwwwwwwwwwwwwwwww"
# #p flow.to_authorization

# gmailapi = client.discovered_api('gmail', 'v1')
# puts "client_secrets444444444444444444444444444444"
# # p flow
# p client_secrets
# puts "plussssssssssssssssssssssssssss"
# p plus
# authorization = client_secrets.to_authorization
 # flow.authorization.fetch_access_token!
# puts "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# # flow.authorization.fetch_access_token!

 # puts "5555555555555555555555555555"
 
 # if session['credentials']
 
    # authorization.update_token!(
      # :access_token => session['credentials']['access_token'],
      # :refresh_token => session['credentials']['refresh_token']
    # )
 # else
# puts "session not found"
 # end
# p flow.authorize
#client.authorization = flow.authorize
# puts "5555555555555555555555555555"
# # Make an API call.
# result = client.execute(
  # :api_method => gmail.users.messages.list,
  # :parameters => {'maxResults' => '1', 'userId' => 'suman.panda@andolasoft.co.in'}
# )

# p result.data

############3rd type of implementation using google service
# api_client = Google::APIClient.new
# path_to_key_file ="API Project-f524d03efe6a.p12"
# passphrase = "notasecret"
# key = Google::APIClient::PKCS12.load_key(path_to_key_file, passphrase)
# asserter = Google::APIClient::JWTAsserter.new(
   # '376013845018-jd2qfkd6b35p7n0ijne8ags5rf47eusv.apps.googleusercontent.com',
   # 'https://accounts.google.com/o/oauth2/auth',
   # key)

# # To request an access token, call authorize:
# api_client.authorization = asserter.authorize()
# puts api_client.authorization.access_token


 ##################Attempt 4
  # gmail = Gmail.new('krishna.sahoo@andolasoft.com', 'krish69')
  # p gmail.inbox.count
  # gmail.inbox.emails(:from => "priyabrata.gharai@andolasoft.com",:maxRecord=>1).each do |email|
    # p email.inspect
  # end
render layout: false
  end
end
