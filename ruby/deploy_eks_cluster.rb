require 'aws-sdk-eks'
require 'aws-sdk-cloudformation'

$eks_stack_name = 'eks-application-cluster'

$statuses_complete = ['CREATE_COMPLETE', 'ROLLBACK_COMPLETE', 'UPDATE_COMPLETE', 'UPDATE_ROLLBACK_COMPLETE', 'DELETE_COMPLETE']

def stack_exists?(client)
    response = client.list_stacks()
    eks_stack = response.stack_summaries.find { |stack| stack.stack_name === $eks_stack_name }
    if eks_stack == nil
        return false;
    elsif eks_stack.stack_status == 'DELETE_COMPLETE'
        return false
    else
        return true
    end
    # return (eks_stack != nil && eks_stack.stack_status != 'DELETE_COMPLETE') || eks_stack != nil
end

def is_stack_in_status(client, statuses)
    response = client.list_stacks()
    eks_stack = response.stack_summaries.find { |stack| stack.stack_name === $eks_stack_name }
    return statuses.include?(eks_stack.stack_status)
end

def get_stack_status(client)
    response = client.list_stacks()
    eks_stack = response.stack_summaries.find { |stack| stack.stack_name === $eks_stack_name }
    return eks_stack.stack_status
end

def create_eks_stack(client)
    template_body = File.read('../cf/eks-cluster.yml')
    parameters = { }
    begin
        response = client.create_stack({
          stack_name: $eks_stack_name,
          template_body: template_body,
          parameters: parameters,
          capabilities: ['CAPABILITY_NAMED_IAM'],
          tags: [
            {
              key: 'Name',
              value: $eks_stack_name
            }
          ]
        })
        puts "Stack #{response.stack_id} is being created"
        wait_until_stack_is_compete(client)
    rescue Aws::CloudFormation::Errors::ServiceError => e
        puts "Failed to create stack: #{e.message}"
    end
end

def update_eks_stack(client)
    template_body = File.read('../cf/eks-cluster.yml')
    parameters = { }
    begin
        response = client.update_stack({
          stack_name: $eks_stack_name,
          template_body: template_body,
          parameters: parameters,
          capabilities: ['CAPABILITY_NAMED_IAM'],
          tags: [
            {
              key: 'Name',
              value: $eks_stack_name
            }
          ]
        })
        puts "Stack #{response.stack_id} is being updated"
        wait_until_stack_is_compete(client)
    rescue Aws::CloudFormation::Errors::ServiceError => e
        puts "Failed to create stack: #{e.message}"
    end
end

def wait_until_stack_is_compete(client) 
    previous_message = nil
    loop do
        sleep(5)
        status = get_stack_status(client)
        message = "The stack: #$eks_stack_name is in status: #{status}"
        if message != previous_message then
            puts message
            previous_message = message
        end
        break if status.include?('_FAILED') or status.include?('_COMPLETE')
    end
end


def run_demo
    client = Aws::CloudFormation::Client.new(region: 'eu-central-1')
    eks_stack_exists = stack_exists?(client)
    eks_stack_ready_for_provisioning = is_stack_in_status(client, $statuses_complete)

    puts "#{$eks_stack_name} exists: #{eks_stack_exists}"
    puts "#{$eks_stack_name} ready for provisioning: #{eks_stack_ready_for_provisioning}"

    if eks_stack_ready_for_provisioning then
        if eks_stack_exists then 
            update_eks_stack(client)
        else
            create_eks_stack(client)
        end
    else
        stack_status = get_stack_status(client)
        puts "The stack: #$eks_stack_name cannot be updated or created because of its status: #{stack_status}"
    end

    # client = Aws::EKS::Client.new(region: 'eu-central-1');
    # response = client.list_clusters();
    # puts "EKS Clusters:"
    # response.clusters.each do |cluster|
    #     puts cluster
    # end

end

run_demo if $PROGRAM_NAME == __FILE__
