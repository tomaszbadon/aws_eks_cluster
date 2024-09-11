require 'aws-sdk-s3'
require './deploy_eks_cluster.rb'

region = 'eu-central-1'
client = Aws::S3::Client.new(region: region)

file_path = '../cf/eks-cluster-roles.yml';
file_content = File.read(file_path)
resp = client.put_object({
  body: file_content, 
  bucket: "bucket-with-stacks", 
  key: "eks-cluster-roles.yml"
})
puts "File #{file_path} has been sent to S3"

file_path = '../cf/network-template.yml';
file_content = File.read(file_path)
resp = client.put_object({
  body: file_content, 
  bucket: "bucket-with-stacks", 
  key: "network-template.yml"
})
puts "File #{file_path} has been sent to S3"

file_path = '../cf/ec2-template.yml';
file_content = File.read(file_path)
resp = client.put_object({
  body: file_content, 
  bucket: "bucket-with-stacks", 
  key: "ec2-template.yml"
})
puts "File #{file_path} has been sent to S3"


eks_stack_name = 'eks-application-cluster'
deployer = StackDeployer.new('eu-central-1', eks_stack_name, '../cf/main-stack.yml')
deployer.deploy()