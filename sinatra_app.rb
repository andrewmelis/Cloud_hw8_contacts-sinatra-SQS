require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/flash'
require 'aws-sdk'

AWS.config()	#grabs vars from role
$s3 = AWS::S3.new()
$sdb = AWS::SimpleDB.new()
$sns = AWS::SNS.new(:region => 'us-west-2')



$url_base = "https://s3.amazonaws.com/melis_assignment_7/"
$domain = $sdb.domains['assignment_7']

get '/' do
  @title = "Index"
  @contacts = $domain.items.select('*')
  erb :index
end

get '/sns' do
  @title = "SNS"
  @topics = Array.new
  @topic_names = Array.new
  $sns.topics.each do |t| 
    @topic_names<<t.name
    @topics<<t.arn
  end
  erb :sns
end

post '/sns' do
  puts params
  $sns.topics[params[:topic]].subscribe(params[:endpoint])
  #flash[:notice] = "Thanks for subscribing to #{params[:topic]}!"
  redirect to('/')
end

get '/new_contact' do
  @title = "New Contact"
  erb :new_contact
end

post '/new_contact' do
  puts params
  name_array = Array.new
  name_array<< params[:first]
  name_array<< params[:last]

  newContact(name_array, $domain)

  redirect to('/')
end

helpers do

  #from http://ididitmyway.herokuapp.com/past/2010/4/25/sinatra_helpers/
  def link_to(url,text=url,opts={})
    attributes = ""
    opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
    "<a href=\"#{url}\" #{attributes}>#{text}</a>"
  end

  def newContact(arr, domain)
    arr.insert(0,SecureRandom.uuid)

    generateSimpleDBContact(arr, domain)

    generateFile(arr)

    sendFile(arr,$s3.buckets["melis_#{domain.name}"])
    
    #send notification to 51083-updated

    publish(arr)
  end

  def publish(arr)
    arn = "arn:aws:sns:us-west-2:405483072970:51083-updated"   
    
    $sns.topics[arn].publish(
      "The new contact\'s name is #{arr[1]} #{arr[2]}.
      You can see their contact page at #{$url_base+arr[1]+'_'+arr[2]+'.html'}",
      :subject => "New Contact Created in 51083")
  end
    


  #create simple_db entry
  def generateSimpleDBContact(contact_array, domain)
    domain.items["#{contact_array[0]}"].attributes['first'].add contact_array[1].downcase
    domain.items["#{contact_array[0]}"].attributes['last'].add contact_array[2].downcase
    #domain.items["#{contact_array[0]}"].attributes['phone'].add contact_array[3]
  end


  #helper function for newContact
  #takes in array with first name, last name, and phone number
  #creates a new html file named using that array
  #returns a the file for use in sending file up to amazon
  def generateFile(arr)
    require 'fileutils'		    #load fileutils module to enable copying behavior

    #copy template_contacts and rename using array
    #FileUtils.cp 'template_contact.html', "./contacts/#{arr[1].downcase}_#{arr[2].downcase}_#{arr[3].downcase}.html"
    FileUtils.cp 'template_contact.html', "./contacts/#{arr[1].downcase}_#{arr[2].downcase}.html"

    #append the following lines representing the next row of html table
    #f = open("./contacts/#{arr[1].downcase}_#{arr[2].downcase}_#{arr[3]}.html", "a") do |f|
    f = open("./contacts/#{arr[1].downcase}_#{arr[2].downcase}.html", "a") do |f|
      f << "<td>#{arr[0]}<td/>\n"
      f << "<td>#{arr[1].capitalize}<td/>\n"
      f << "<td>#{arr[2].capitalize}<td/>\n"
      #    f << "<td>#{arr[3]}<td/>\n"
      f << "</tr>\n</table>"
    end
  end

  #helper function for newContact
  def sendFile(arr,bucket)
    f = open("./contacts/#{arr[1].downcase}_#{arr[2].downcase}.html", 'r')
    bucket.objects["#{arr[1].downcase}_#{arr[2].downcase}.html"].write(f, :acl => :public_read)
  end


end



