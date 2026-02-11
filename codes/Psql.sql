-- ==========================================
-- PROJECT: MEDTECH COGNITIVE ENTERPRISE ARCHITECTURE
-- AUTHOR: MOHAMED ADNAN PALLI KONDA
-- TARGET: POSTGRESQL (OPERATIONAL LAYER)
-- ==========================================

-- 0. SETUP EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. DOMAIN: MASTER_DATA
CREATE TYPE org_type AS ENUM ('Internal_Branch', 'Distributor', 'Customer');
CREATE TYPE user_role AS ENUM ('Technician', 'Manager', 'Auditor', 'QA');

CREATE TABLE organizations (
    org_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type org_type NOT NULL,
    country_code VARCHAR(5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    role user_role NOT NULL,
    home_branch_id UUID REFERENCES organizations(org_id),
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE product_catalog (
    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_name TEXT NOT NULL,
    risk_class VARCHAR(10), -- Class I, II, III
    specifications JSONB
);

CREATE TABLE assets (
    asset_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    serial_number TEXT UNIQUE NOT NULL,
    model_id UUID REFERENCES product_catalog(model_id),
    owner_org_id UUID REFERENCES organizations(org_id),
    warranty_expiry DATE,
    current_status TEXT DEFAULT 'Active'
);

-- 2. DOMAIN: SERVICE_OPS
CREATE TABLE service_orders (
    so_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_id UUID REFERENCES assets(asset_id),
    handling_branch_id UUID REFERENCES organizations(org_id), -- The workshop hub
    customer_org_id UUID REFERENCES organizations(org_id),    -- The client/distributor
    current_stage TEXT DEFAULT 'Intake',
    priority_level INT DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE triage_events (
    triage_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    so_id UUID REFERENCES service_orders(so_id) ON DELETE CASCADE,
    inspector_id UUID REFERENCES users(user_id),
    findings JSONB,
    estimated_parts JSONB,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE repair_jobs (
    job_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    so_id UUID REFERENCES service_orders(so_id) ON DELETE CASCADE,
    technician_id UUID REFERENCES users(user_id),
    labor_minutes INT DEFAULT 0,
    job_details TEXT,
    completed_at TIMESTAMP
);

-- 3. DOMAIN: COMPLIANCE & AUDIT
CREATE TABLE compliance_checks (
    check_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    so_id UUID REFERENCES service_orders(so_id) UNIQUE,
    qa_manager_id UUID REFERENCES users(user_id),
    is_passed BOOLEAN DEFAULT FALSE,
    electronic_signature_hash TEXT, -- SHA-256 Hash for non-repudiation
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_log_history (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    old_value JSONB,
    new_value JSONB,
    changed_by UUID REFERENCES users(user_id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. LOGISTICS & INVENTORY
CREATE TABLE inventory_transactions (
    trans_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    so_id UUID REFERENCES service_orders(so_id),
    movement_type TEXT, -- e.g., 'PART_CONSUMPTION'
    part_id UUID NOT NULL,
    quantity INT DEFAULT 1,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. PERFORMANCE INDEXES
CREATE INDEX idx_so_asset ON service_orders(asset_id);
CREATE INDEX idx_so_branch ON service_orders(handling_branch_id);
CREATE INDEX idx_audit_record ON audit_log_history(record_id);
CREATE INDEX idx_asset_serial ON assets(serial_number);

-- 6. STORED PROCEDURES (WORKFLOW LOGIC)
-- Rule: Prevent Service Order from closing without a PASSED compliance check
CREATE OR REPLACE FUNCTION check_qa_before_dispatch()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.current_stage = 'Dispatched' THEN
        IF NOT EXISTS (
            SELECT 1 FROM compliance_checks 
            WHERE so_id = NEW.so_id AND is_passed = TRUE
        ) THEN
            RAISE EXCEPTION 'Compliance Failure: Service Order cannot be Dispatched without a passed QA Check.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_dispatch
BEFORE UPDATE OF current_stage ON service_orders
FOR EACH ROW EXECUTE FUNCTION check_qa_before_dispatch();

-- 7. AUDIT TRIGGER (GENERIC)
CREATE OR REPLACE FUNCTION log_record_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log_history (table_name, record_id, old_value, new_value)
    VALUES (TG_TABLE_NAME, COALESCE(OLD.so_id, NEW.so_id), to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_so
AFTER UPDATE ON service_orders
FOR EACH ROW EXECUTE FUNCTION log_record_changes();

-- ==========================================
-- END OF SCRIPT
-- ==========================================
