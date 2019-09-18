-- This script should be run as superuser (postgres) AFTER the first successful deployment of VIPSLogic 
-- DON'T FORGET TO EDIT WITH YOUR OWN INFO
-- psql -f init_org_and_user.sql vipslogic

-- In case you forgot until now...
ALTER ROLE vipslogic NOSUPERUSER;

-- SETUP organization AND first admin user

INSERT INTO organization (organization_id, organization_name, parent_organization_id, address1, address2, postal_code, country_code, default_locale, default_map_center, default_map_zoom, default_time_zone, city, default_vips_core_user_id, vipsweb_url) 
VALUES (
	1, -- organization_id
	'VIPS Norge', -- organization_name
	NULL, -- parent_organization_id (normally not in use, consider deprecated)
	'Postboks 115', -- address1
	NULL, -- address2
	'1431', -- postal_code (ZIP)
	'NO', -- country_code Ref. table public.country
	'nb', -- default_locale Ref. https://docs.oracle.com/javase/8/docs/api/java/util/Locale.html 
	ST_GeomFromText('POINT(10.00015 68.432044)', 4326), -- default_map_center 
	4, -- default_map_zoom (OpenLayers zoom level)
	'Europe/Oslo', -- default_time_zone Ref. https://docs.oracle.com/javase/8/docs/api/java/util/TimeZone.html
	'Ås', -- city
	1, -- default_vips_core_user_id
	'http://www.vips-landbruk.no/' -- vipsweb_url URL to the public website
);


INSERT INTO vips_logic_user (user_id, email, first_name, last_name, organization_id, remarks, user_status_id, vips_core_user_id, preferred_locale, phone, approves_sms_billing, phone_country_code, free_sms) 
VALUES (
	1, -- user_id
	'foo.bar@foobar.com', -- user_email 
	'Foo', -- first_name
	'Bar', -- last_name
	1, -- organization_id
	'Created at application initialization', -- General remarks about user 
	4, -- user_status_id 4 = approved
	1, -- vips_core_user_id = Which user id you have in the VIPSCoreManager auth system
	'en', -- preferred_locale Ref. https://docs.oracle.com/javase/8/docs/api/java/util/Locale.html 
	'21324354', -- phone (without country code) 
	true, -- approves_sms_billing If true = Approves to the SMS service provider that billing is OK
	'47', -- phone_country_code
	true -- free_sms If true = receive free SMSs from the SMS service provider
);

INSERT INTO user_vips_logic_role (vips_logic_role_id, user_id) VALUES (1,1); -- super user

INSERT INTO user_authentication (user_id, user_authentication_type_id, username, password) 
VALUES (
	1, -- user_id
	1, -- authentication_type_id Ref public.user_authentication_type (Password in this example)
	'foobar', -- username
	'XXXXXXXXXXXXXXXX' -- password, MD5 encrypted with the no.nibio.vips.logic.MD5_SALT (see the appserver configuration settings)
);
