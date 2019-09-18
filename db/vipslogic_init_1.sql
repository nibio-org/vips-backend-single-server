-- This script must be run as superuser (postgres)
-- Before you deploy VIPSLogic

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

CREATE USER vipslogic WITH PASSWORD :vipslogic_password;

CREATE DATABASE vipslogic
  WITH OWNER = vipslogic
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       CONNECTION LIMIT = -1;


-- WE NEED TO DO THIS IN ORDER TO MAKE flywaydb RUN THE INITIAL MIGRATION
-- MAKE SURE YOU REVOKE THIS PRIVILEGE AFTER FIRST DEPLOYMENT OF VIPSLOGIC
-- (Like this: ALTER ROLE vipslogic NOSUPERUSER;)

ALTER ROLE vipslogic SUPERUSER;
