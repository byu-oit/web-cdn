# BYU Web Community CDN

Welcome the source of the BYU Web Community CDN!  This CDN aims to host all the resources you need to use the
official BYU Look and Feel on your website.

The CDN is now maintained by OIT. The source code for the previous version 1 of the CDN can be found in the 
[BYU Web GitHub organization](https://github.com/byuweb/web-cdn).

## Adding Libraries to the CDN

See [the checklist](docs/adding-libraries.md)

## Usage

Go to [https://brand.byu.edu](https://brand.byu.edu) to learn about the BYU theme.

## How it works

The CDN is governed by the [main-config.yml](main-config.yml) file in this repository.  This file references other
repositories, from which we pull the contents for the CDN.
Whenever a change is pushed to this repo or any of the repositories it references, a rebuild of the CDN contents
will be triggered.

The CDN itself is hosted in Amazon S3 and served through Amazon Cloudfront. This allows us to have very high uptime
guarantees and grants us simplicity in deployment. It also give us great analytics about the usage of the CDN.

## CDN Layout

The basic URL pattern for hosted libraries is as follows:

`https://cdn.byu.edu/{libraryName}/{version}`

By default, a version will be created for each tag/release in the library's repository. In addition, versions
will be created for each major and minor version, to allow consumers to easily get updates to the libraries they consume.
Finally, a `latest` version will be included with a reference to the latest release/tag, as determined by semver rules.

Let's say that your project has the following tags/releases:

* 1.0.0
* 1.0.1
* 1.0.2
* 1.1.0
* 1.1.1
* 2.0.0

Here's what version paths will be created for your library:

* 1.0.0
* 1.0.1
* 1.0.2
* 1.1.0
* 1.1.1
* 2.0.0
* 1.x.x -> 1.1.1
* 1.0.x -> 1.0.2
* 1.1.x -> 1.1.1
* 2.x.x -> 2.0.0
* 2.0.x -> 2.0.0
* latest -> 2.0.0

This allows a consumer to decide how automatic they want updates to be for their dependencies. Most users should generally
use the major version - `1` or `2` in this case - to get all future non-breaking updates to a dependency. If a user
wants to be more cautious, they can reference a minor version - `1.1` - to get only bug fix updates, not new feature
updates.

Additional URL endpoints also exist to access git branches and tags. For that information you'll want to
[read about aliases](./docs/aliases.md).

## Criteria for hosting

In order for us to host code in this CDN, the code must either be built by the Web Community for use by campus, or
must be generally useful to a large number of campus sites.  In general, the following things must be true:

1. The code must be of high quality and relatively free of defects.
2. There must be a commitment on the part of the contributing department to oversee the maintenance and improvement of
the code indefinitely, including implementation of any future changes to the official BYU Look and Feel. Just because
the Web Community is hosting it doesn't mean that we have the time or resources to maintain your code!
3. For Javascript code, automated regression and unit tests must be included in the project, covering a reasonable percentage
of the project's use cases.
4. The code or resources must have clear documentation about how to consume them.

## Deployment instructions

The following instructions should be used to deploy the CDN into a new AWS account. These steps should be done manually 
in the AWS console. Defaults should be used unless otherwise specified. However, **all resources created in us-east-1**.
Be sure to include the [required tags](https://github.com/byu-oit/BYU-AWS-Documentation#tagging-standard) where 
possible for all resources created.

1. Create a new CloudFormation stack using [account-and-iam.yml](.aws-infrastructure/account-and-iam.yml) as the 
template. Give the stack a name of `web-community-cdn-account` and specify other parameters. The CDNName parameter 
should be "web-community-cdn".
2. To deploy to any environment besides `dev` and `prd`, add the environment to files [env-template](./.aws-infrastructure/environment-template.mustache.yml),
[cdn-assembler](./assembler/bin/cdn-assembler.js), and [main-config](main-config.yml)
3. Create a new Route 53 Hosted Zone with an appropriate URl:
   - cdn.byu.edu (PRD)
   - cdn-dev.byu.edu (DEV)
4. Use [this order form](https://it.byu.edu/it/?id=sc_cat_item&sys_id=2f7a54251d635d005c130b6c83f2390a) to request an NS 
record pointing to the NS servers in the created hosted zone. Wait for that request to be completed before moving on.
5. Create a new ACM certificate for the URL used in step two, and the subdomain. For example, `cdn-dev.byu.edu` _and_ `*.cdn-dev.byu.edu`. After it is made, 
click the "Create record in Route 53" to link the certificate to the Route 53 zone you have created. Once complete, wait for AWS to validate the 
certificate before continuing. 
6. Update the certificate ARN and URL for the appropriate stage in the infrastructure section of 
[main-config.yml](main-config.yml), and in the [deployment GitHub action](./.github/workflows/deploy.yml)
7. Create the following parameters in SSM Parameter Store:
  - ~~`web-community-cdn.{env}.slack-webhook`: The webhook CDN update alerts should be sent to~~
  - ~~`web-community-cdn.{env}.slack-channel`: The channel CDN update alerts should be sent to~~
  - `web-community-cdn.{env}.github-user`: The GitHub user to connect to GitHub with.
  - `web-community-cdn.{env}.github-token`: The token of the user to connect to GitHub with.
8. Push changes to the GitHub repo and watch the GitHub action deployment for any issues. Wait for it to successfully deploy its CloudFormation 
template before continuing (the pipeline will fail because DNS isn't completely setup yet).
9. Copy the validation CNAME record from the original hosted zone create to the hosted zone (with the same name) 
created by CloudFormation. 
10. Use [the same order form](https://it.byu.edu/it/?id=sc_cat_item&sys_id=2f7a54251d635d005c130b6c83f2390a) to request 
the NS record for the URL points to the NS servers in the CloudFormation-created hosted zone. Wait for that request to 
be completed and for changes to propagate before moving on.
11. Rerun the pipeline in GitHub actions so that it can finish successfully.
12. Delete the manually created hosted zone.

## Architecture
The CDN's main architecture uses AWS Cloudfront and S3 to server up files (which is similar to a typical static website). 
Additionally, these parts exist:
- [Eager Redirect Edge Lambda](edge-lambdas/eager-redirect)
    - Called before going to the s3 bucket
    - This lambda is primarily responsible for redirecting aliases so that the calls don't need to 
      go to the s3 bucket first to redirect (which makes it faster).
- [Enhanced Headers Edge Lambda](edge-lambdas/enhanced-headers)
    - Called after going to the s3 bucket
    - Changes 301 redirects to 302 redirects
    - Takes S3 metadata and adds them as http headers
- The ["assembler"](assembler)
  - This deploys libraries into the CDN and all relevant metadata
  - There is a ["webhook" lambda](webhooks) function that is invoked via Github webhooks
    - When invoked it starts a code build process that starts the main assembler process
  - The codebuild process does several things:
    - It uses the [main-config.yml](main-config.yml) file to set what repositories it pulls from and some options for the those libraries/assets
    - It determines what has changed in code and what new branches exist that need to be pushed to the S3 bucket and does so
    - It produces a redirects.json and redirects.json.gz file in the .cdn-infra directory in the s3 bucket
        - The Eager Redirect Lambda uses this to eagerly redirect aliases
    - It also produces a mainfest.json file that has information about all the branches of Github repos
      used as sources for libraries
        - The manifest helps manage finding the difference between what has been deployed and what needs to be deployed.
- [Log Analyzer Sorter Lambda](log-analyzer)
  - Helps organize cloudwatch access logs by date
  - This lambda is triggered by adding a s3 object to the access log bucket
  - It makes a copy of the s3 file to another path that is organized like /year-month/day/hour/{file}
  - This lambda may not be necessary, but is a good way to partition (if we were doing so)
    - Mostly in line with this recommendation for partitioning: https://aws.amazon.com/blogs/big-data/analyze-your-amazon-cloudfront-access-logs-at-scale/

## TODOs

- Remove redundant files (wishlist.md, etc.)
- Switch to Terraform
- Use latest recommended node version
- Cache docker images
- Use a GitHub bot we can control
- Add tests
- Solidify name (web-cdn, web-community-cdn, etc.)
