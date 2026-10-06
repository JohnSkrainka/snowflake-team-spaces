-- Proves each team gets its own space and can't reach anyone else's.
-- Run in Snowsight as your own admin user after `terraform apply` (dev
-- workspace), ONE statement at a time (Cmd/Ctrl+Enter). Lines marked
-- EXPECT FAIL are supposed to error.

-- Snowflake keeps all your roles active by default, so you'd still be
-- ACCOUNTADMIN after USE ROLE and nothing would fail. Turn that off.
USE SECONDARY ROLES NONE;


-- 1. Marketing works in its own space -------------------------------------
USE ROLE DEV_MARKETING;
USE WAREHOUSE DEV_MARKETING_WH;

CREATE TABLE DEV_MARKETING_DB.MAIN.CAMPAIGNS (campaign STRING, spend NUMBER(10, 2));
INSERT INTO DEV_MARKETING_DB.MAIN.CAMPAIGNS VALUES ('fall_promo', 1200.00), ('webinar', 300.00);
SELECT * FROM DEV_MARKETING_DB.MAIN.CAMPAIGNS;


-- 2. ...and can't touch finance's ------------------------------------------
CREATE TABLE DEV_FINANCE_DB.MAIN.SNEAKY (id INT);  -- EXPECT FAIL: no access to finance's database
USE WAREHOUSE DEV_FINANCE_WH;                    -- EXPECT FAIL: compute is per team


-- 3. Finance has the same setup, plus a keyless service user (count = 1) --
USE ROLE DEV_FINANCE;
USE WAREHOUSE DEV_FINANCE_WH;
CREATE TABLE DEV_FINANCE_DB.MAIN.INVOICES (invoice_id INT, amount NUMBER(10, 2));
GRANT SELECT ON TABLE DEV_FINANCE_DB.MAIN.INVOICES TO ROLE DEV_MARKETING;  -- EXPECT FAIL: managed access, only SECURITYADMIN can grant
SELECT * FROM DEV_MARKETING_DB.MAIN.CAMPAIGNS;     -- EXPECT FAIL: can't see marketing

USE ROLE SECURITYADMIN;
SHOW USERS LIKE 'DEV_%_SVC';                     -- only DEV_FINANCE_SVC
SHOW GRANTS TO ROLE DEV_MARKETING;               -- everything team_access granted

-- No password, no key: the service user trusts finance's IAM role. The ARN
-- here is the one Terraform created in AWS (terraform output teams).
SHOW USER WORKLOAD IDENTITY AUTHENTICATION METHODS FOR USER DEV_FINANCE_SVC;


-- 4. Drift: someone "just fixes it" in the UI --------------------------------
USE ROLE SYSADMIN;
ALTER WAREHOUSE DEV_MARKETING_WH SET WAREHOUSE_SIZE = 'LARGE';
-- Now `terraform plan` shows it going back to XSMALL.
