# DeploySqlServerSecurity
A bottom up rebuild of: https://github.com/Alex-Yates/GeneratePermissions

This repo is currently a thought experiment of just psuedo code

The idea is that you could baseline your security by running GetSecurity.ps1. This will read a source database and populate the .json files in /source/ with all the info about the users/roles in a database. You could also tag this data with an environment tag (e.g. "dev" or "prod") allowing you to version the security for different environments separately.

The /source/ directory contains example JSON. These files would initially be generated by /GetSecurity.ps1 but then they would be maintained by DBAs etc.

The /deploy/ directory contains a couple of scripts, one to make sure all the security defined here is deployed (or corrected) based on the JSON version. The other is designed to tear down any security that does not exist in the source. This could be run on a regular basis to alert folks about any unexpected users that have been added to the system and to enforce acces controls etc.

The /test/ directory would contain a bunch of pester tests to make sure that, for example, referential integrity is maintained in the JSON, that all users have an associated login and a default schema, and that all users have an appropriate environment tag. This could be run as part of a build process, for example, to catch any typos or mistakes with config.

I'm currently looking for feedback on the general concept. Please feel free to add a GitHub issue with any feedback you may have.
