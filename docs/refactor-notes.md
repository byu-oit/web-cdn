# Lessons learned from refactor / rebuild investigation

## What is a CDN?
AWS CDN documentation: [What is a CDN?](https://aws.amazon.com/what-is/cdn/)
In short a CDN (or content delivery network) is a mechanism by which one can distribute resources to speed up website load times. It also provides a standardization level for usage of common components. Amazon's cloudfront offering provides this ability for us to add links to our cdn which provide developers a single location to receive standardized components for web pages.

## BYUWEB/WEB-CDN
### Issues:
The [byuweb/wed-cdn](https://github.com/byuweb/web-cdn) repository reaches across several repositories within the byuweb organization to compile their components and ship them to centralized cdn hub.

Issues:
> The existing ci/cd pipeline is built using outdated patterns. For example the extensive use of deployment scripts instead of github actions.
> It generally has not been updated in 4 years. Brock updated the codebuild to use node 14 in our repo but the rest of the code hasn't been invesitgated in years.
> We honestly need the process redfined if this is a service we are willing to offer and if so what that new future looks like. The environment has changed and this is no longer functioning the way it was originally intended. For example no one from the web community contributes to it.
