require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/flash'
require 'aws-sdk'

#AWS.config()	#grabs vars from role
AWS.config(:access_key_id => ENV['AWS_ACCESS_KEY'], :secret_access_key => ENV['AWS_SECRET_KEY'])	#grabs vars from role
$s3 = AWS::S3.new()
$sdb = AWS::SimpleDB.new()
$sns = AWS::SNS.new(:region => 'us-west-2')
$sqs = AWS::SQS.new(:region => 'us-west-2')

#Thread.new{system("ruby queue.rb #{$s3} #{$sns} #{$sqs}")}
#q = SQSQueue.new($s3,$sns,$sqs)
#Thread.new {SQSQueue.new($s3,$sns,$sqs)}


$url_base = "https://s3.amazonaws.com/melis_assignment_8/"
$domain = $sdb.domains['assignment_8']

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

    send_to_queue(arr)

    #Thread.new {$q.start}	#if don't start on new thread, web page hangs

    #old process, now moved to queue
    #generateFile(arr)

    #sendFile(arr,$s3.buckets["melis_#{domain.name}"])
    #
    ##send notification to 51083-updated

    #publish(arr)
  end

  
  def send_to_queue(arr)
    queue = $sqs.queues.named("assignment_8_dev")
    queue.send_message("#{arr[0]} #{arr[1]} #{arr[2]}")
  end

  #create simple_db entry
  def generateSimpleDBContact(contact_array, domain)
    domain.items["#{contact_array[0]}"].attributes['first'].add contact_array[1].downcase
    domain.items["#{contact_array[0]}"].attributes['last'].add contact_array[2].downcase
    #domain.items["#{contact_array[0]}"].attributes['phone'].add contact_array[3]
  end


  
end



