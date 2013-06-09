require 'aws-sdk'


#AWS.config()	#grabs vars from role
AWS.config(:access_key_id => ENV['AWS_ACCESS_KEY'], :secret_access_key => ENV['AWS_SECRET_KEY'])	#grabs vars from role
s3 = AWS::S3.new()
sns = AWS::SNS.new(:region => 'us-west-2')
sqs = AWS::SQS.new(:region => 'us-west-2')


class SQSQueue

  attr_reader :s3, :sns, :sqs, :queue, :url_base, :domain


  def initialize(s3,sns,sqs)
    @s3 = s3
    @sns = sns
    @sqs = sqs
    @url_base = "https://s3.amazonaws.com/melis_assignment_8/"
    @domain = 'assignment_8'

    @queue = @sqs.queues.named("assignment_8_dev")
    start
  end

  def start
    @queue.poll(:wait_time_seconds => 20) do |msg|
    #@queue.poll() do |msg|
      arr = parse_message(msg)
      msg.delete		#not totally necessary as retrieval in block form deletes msg automatically
      #check if exists?
      generateFile(arr)
      sendFile(arr,@s3.buckets["melis_#{@domain}"])
      publish(arr)
    end
  end
  
  def parse_message(msg)
    msg.body.split
  end
  #
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

  def publish(arr)
    arn = "arn:aws:sns:us-west-2:405483072970:51083-updated"   
    
    @sns.topics[arn].publish(
      "The new contact\'s name is #{arr[1]} #{arr[2]}.
      You can see their contact page at #{@url_base+arr[1]+'_'+arr[2]+'.html'}",
      :subject => "New Contact Created in 51083")
  end
  
end
    

SQSQueue.new(s3,sns,sqs)
