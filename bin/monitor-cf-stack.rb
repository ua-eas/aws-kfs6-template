#
# This program monitors a given CloudFormation stack and watches for completion or errors.
#
# This program required the following gems:
#   thor

require "thor"
require "aws-sdk"

class CloudFormation

  @monitoredEvents = Array.new
  
  def monitorStack(stackname=nil)
    @monitoredEvents = Array.new
    check_interval = 20
    max_checks = 3600 / check_interval
    check_count = 0
    keepGoing = true
    
    while keepGoing
      keepGoing = checkOnce(stackname)
      sleep check_interval
      
      if check_count > max_checks
        raise "Timeout while monitoring CloudFormation template"
      end
      
      check_count += 1
      
    end
  end

  def checkOnce(stackname=nil)
    puts "Checking Stack: #{stackname}"
    Aws.config.update({
      region: 'us-west-2',
    })
    
    cf = Aws::CloudFormation::Client.new
    resp = cf.describe_stack_events({ stack_name: stackname })
    events = resp.stack_events
    events.each do |event|
      # We're only interested in certain event statuses:
      # CREATE_FAILED  CREATE_COMPLETE  UPDATE_FAILED
      if !["CREATE_FAILED", "CREATE_COMPLETE", "UPDATE_FAILED"].include? event.resource_status
        next
      end
      
      # If we've seen this event already, skip it
      if @monitoredEvents.include? event.event_id
        next
      end
      
      # Add this event to the list
      @monitoredEvents << event.event_id

      puts "#{event.logical_resource_id}: #{event.resource_status} #{event.resource_status_reason}"
      
      # If the resource is the stack name, see if its complete or failed
      if event.logical_resource_id == stackname
        if event.resource_status == "CREATE_COMPLETE"
          # exit the script successfully
          exit
        end
        if event.resource_status == "CREATE_FAILED" or event.resource_status == "UPDATE_FAILED"
          # exit the script with error
          exit 1
        end
      end
      
    end # events.each
    
    return true

  end


end



class MonitorCloudFormationStack < Thor
  @@cf = CloudFormation.new
  
  desc "monitor NAME", "Monitor stack NAME for changes and completion state."
  def monitor(stackname=nil)
    @@cf.monitorStack(stackname)
  end
  
end
 
MonitorCloudFormationStack.start(ARGV)

