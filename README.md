# Deploying a Docker Application on AWS Elastic Beanstalk with GitLab
> Many customers rely on AWS Elastic Beanstalk to manage the infrastructure provisioning, monitoring, and deployment of their web applications.  While Elastic Beanstalk supports several development platforms and languages, its support for Docker applications provides the most flexibility for developers to define their own stacks and achieve faster delivery cycles.
At the same time, organizations want to automate their build, test, and deployment processes and leverage continuous methodologies with modern DevOps platforms like GitLab. In this blog post, we will walk you through a process to build a simple Node.js application as a Docker container, host that container image in GitLab Container Registry, and use GitLab CI/CD and GitLab Runner to create a deployment pipeline to build the Docker image and push it to the Elastic Beanstalk environment.

## Solution Overview
The solution deployed in this blog post will complete the following steps in your AWS account:
1.	Setup the initial GitLab Environment on Amazon EC2 in a new Amazon VPC and populate a GitLab code repository with a simple Node.js application. This step will also configure a deployment pipeline involving GitLab CI/CD, GitLab Runner and GitLab Container Registry.
2.	Login and setup SSH access to your GitLab environment and configure GitLab CI/CD deployment tokens.
3.	Provision a sample AWS Elastic Beanstalk application and environment.
4.	Update the application code in the GitLab repository and automatically initiate the build and deployment to Elastic Beanstalk with GitLab CI/CD.

## Setup
> For step by step setup of the blog content, please follow the steps here: 
### Dockerrun.aws.json template file:
> A Dockerrun.aws.json file describes how to deploy a remote Docker image as an Elastic Beanstalk application. In our case, our docker image is stored in the “GitLab container registry” and we will point to this “image” location and specify that in this file. For more information about Dockerrun.aws.json file contents, please check this link. The important section in our case is “Image” section in this configuration file. It specifies the Docker base image on an existing Docker repository from which you’re building a docker container.
Since we are using “GitLab” for CI/CD, whenever we make some changes to the code, the pipeline will execute and will create a new container image file in the GitLab container registry. Since we do not know the “image” name ahead, we cannot hardcode this value. For this we will create a template file first and will replace the “image” name dynamically with in the GitLab CI/CD pipeline using “.gitlab-ci.yml” file.

```
{
  "AWSEBDockerrunVersion": "1",
  "Authentication": {
    "Bucket": "$s3_bucket_name",
    "Key": ".dockercfg"
  },
  "Ports": [
  {
    "ContainerPort": "8080"
  }
  ],
  "Image": {
    "Name": "$image_name",
    "Update": "true"
  }
}
```

> Here we are specifying the “.dockercfg” file under “Authentication” section. The location needs to be in an S3 bucket. The s3 bucket name is also defined in the .gitlab-ci.yml file and will be passed to this template file to generate the actual file. Note that “.dockercfg” file was created in the previous section.
In the “Image” section, we are not hardcoding the “image” name. Instead we are specifying this as a variable and in the “.gitlab-ci.yml” file, we will update this value dynamically whenever the new image is created in the GitLab container registry.

### .gitlab-ci.yml file:
> GitLab Ci/CD pipelines are configured using a YAML file called “.gitlab-ci.yml”. We need to create this file in the application root directory. It defines structure and order of the pipeline and decides what to execute in the “GitLab Runner”. This file is also provided in the above sample-nodejs-app zip file.

