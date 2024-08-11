require 'aws-sdk-eks'
require 'aws-sdk-cloudformation'

class StackDeployer

    def initialize(region, stack_name, template_location)
        @statuses_complete = ['CREATE_COMPLETE', 'ROLLBACK_COMPLETE', 'UPDATE_COMPLETE', 'UPDATE_ROLLBACK_COMPLETE', 'DELETE_COMPLETE']
        @stack_name = stack_name
        @template_location = template_location
        @region = region
    end

    def deploy()
        @client = Aws::CloudFormation::Client.new(region: @region)
        eks_stack_exists = stack_exists?()
        puts "Stack: #{@stack_name} exists: #{eks_stack_exists}"

        eks_stack_ready_for_provisioning = is_stack_in_status()
        puts "Stack #{@stack_name} ready for provisioning: #{eks_stack_ready_for_provisioning}"
    
        if eks_stack_ready_for_provisioning then
            if eks_stack_exists then 
                update_eks_stack()
            else
                create_eks_stack()
            end
        else
            stack_status = get_stack_status()
            puts "The stack: #@stack_name cannot be updated or created because of its status: #{stack_status}"
        end
    end

    private def stack_exists?()
        response = @client.list_stacks()
        eks_stack = response.stack_summaries.find { |stack| stack.stack_name === @stack_name }
        if eks_stack == nil
            return false;
        elsif eks_stack.stack_status == 'DELETE_COMPLETE'
            return false
        else
            return true
        end
    end
    
    private def is_stack_in_status()
        response = @client.list_stacks()
        eks_stack = response.stack_summaries.find { |stack| stack.stack_name === @stack_name }
        return @statuses_complete.include?(eks_stack.stack_status)
    end
    
    private def get_stack_status()
        response = @client.list_stacks()
        eks_stack = response.stack_summaries.find { |stack| stack.stack_name === @stack_name }
        return eks_stack.stack_status
    end
    
    private def create_eks_stack()
        template_body = File.read(@template_location)
        parameters = { }
        begin
            response = @client.create_stack({
              stack_name: @stack_name,
              template_body: template_body,
              parameters: parameters,
              capabilities: ['CAPABILITY_NAMED_IAM'],
              tags: [
                {
                  key: 'Name',
                  value: @stack_name
                }
              ]
            })
            puts "Stack #{response.stack_id} is being created"
            wait_until_stack_is_compete()
        rescue Aws::CloudFormation::Errors::ServiceError => e
            puts "Failed to create stack: #{e.message}"
        end
    end
    
    private def update_eks_stack()
        template_body = File.read('../cf/eks-cluster.yml')
        parameters = { }
        begin
            response = @client.update_stack({
              stack_name: @stack_name,
              template_body: template_body,
              parameters: parameters,
              capabilities: ['CAPABILITY_NAMED_IAM'],
              tags: [
                {
                  key: 'Name',
                  value: @stack_name
                }
              ]
            })
            puts "Stack #{response.stack_id} is being updated"
            wait_until_stack_is_compete()
        rescue Aws::CloudFormation::Errors::ServiceError => e
            puts "Failed to create stack: #{e.message}"
        end
    end
    
    private def wait_until_stack_is_compete() 
        previous_message = nil
        loop do
            sleep(5)
            status = get_stack_status()
            message = "The stack: #@stack_name is in status: #{status}"
            if message != previous_message then
                puts message
                previous_message = message
            end
            break if status.include?('_FAILED') or status.include?('_COMPLETE')
        end
    end

end




def run_demo
    eks_stack_name = 'eks-application-cluster'
    deployer = StackDeployer.new('eu-central-1', eks_stack_name, '../cf/eks-cluster.yml')
    deployer.deploy()
end

run_demo if $PROGRAM_NAME == __FILE__
