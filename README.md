# DeploySqlServerSecurity
A bottom up rebuild of: https://github.com/Alex-Yates/GeneratePermissions

Still a work in progress. A simple way to version your database level security in an environment aware manner. (Users, role memberships etc.)

Basic concept:
1. Run GetSecurity.ps1 to generate source code for your users and role memberships. (Possibly also your roles as well, but I'd prefer to assume users are practicing role based security and that the roles are saved in an SSDT or Redgate source control project etc). Users are saved in a JSON (to do: or XML?) format with a tag defining which environment the users are supposed to live in ("DEV", "PROD" etc). (I.E. handling the problem that the production users and dev users should probably be different.) 
2. DBAs (for example) will manage these simple json/xml source files. This allows full audit of access controls via source control.
3. Changes are deployed by running DeploySecurity.ps1. This script will deploy the security, as defined by the JSON/XML files on a per environment basis.

TestSecurity.ps1 will contain a bunch of pester tests to make sure that, for example, referential integrity is maintained in the JSON, that all users have an associated login and a default schema, and that all users have an appropriate environment tag. This could be run as part of a build process, for example, to catch any typos or mistakes with config.

I'm currently looking for feedback on the general concept. Please feel free to add a GitHub issue with any feedback you may have.
