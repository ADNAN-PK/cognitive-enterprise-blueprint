import psycopg2
from faker import Faker
import random
import uuid
from datetime import datetime, timedelta

# Database Connection Settings
DB_CONFIG = {
    "host": "your_host",
    "database": "your_db",
    "user": "your_user",
    "password": "your_password",
    "port": "5432"
}

fake = Faker()

def populate_data():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        print("Connected to PostgreSQL. Starting population...")

        # 1. Create Organizations (Internal vs External)
        org_ids = []
        for _ in range(10):
            org_id = str(uuid.uuid4())
            name = fake.company()
            org_type = random.choice(['Internal_Branch', 'Distributor', 'Customer'])
            cur.execute("INSERT INTO organizations (org_id, name, type, country_code) VALUES (%s, %s, %s, %s)",
                        (org_id, name, org_type, fake.country_code()))
            org_ids.append(org_id)
        
        # 2. Create Users (Assigned to internal branches)
        user_ids = []
        internal_orgs = [o for o in org_ids] # Simplified for dummy data
        for _ in range(50):
            user_id = str(uuid.uuid4())
            role = random.choice(['Technician', 'Manager', 'QA'])
            cur.execute("INSERT INTO users (user_id, username, role, home_branch_id) VALUES (%s, %s, %s, %s)",
                        (user_id, fake.user_name(), role, random.choice(internal_orgs)))
            user_ids.append(user_id)

        # 3. Create Product Catalog & Assets
        product_ids = []
        for _ in range(20):
            p_id = str(uuid.uuid4())
            cur.execute("INSERT INTO product_catalog (model_id, device_name, risk_class) VALUES (%s, %s, %s)",
                        (p_id, f"MedScanner {fake.word().upper()}", random.choice(['Class I', 'Class II', 'Class III'])))
            product_ids.append(p_id)

        asset_ids = []
        for _ in range(200):
            a_id = str(uuid.uuid4())
            cur.execute("INSERT INTO assets (asset_id, serial_number, model_id, owner_org_id, warranty_expiry) VALUES (%s, %s, %s, %s, %s)",
                        (a_id, fake.bothify(text='??-########'), random.choice(product_ids), random.choice(org_ids), fake.future_date()))
            asset_ids.append(a_id)

        # 4. Generate 1,000 Service Orders & Workflows
        print("Generating 1,000 Service Orders...")
        stages = ['Intake', 'Triage', 'Repair', 'QA_Pending', 'Ready_to_Dispatch', 'Dispatched']
        
        for _ in range(1000):
            so_id = str(uuid.uuid4())
            asset_id = random.choice(asset_ids)
            handling_branch = random.choice(internal_orgs)
            customer = random.choice(org_ids)
            current_stage = random.choice(stages)
            
            cur.execute("INSERT INTO service_orders (so_id, asset_id, handling_branch_id, customer_org_id, current_stage) VALUES (%s, %s, %s, %s, %s)",
                        (so_id, asset_id, handling_branch, customer, current_stage))

            # Simulate Triage for most orders
            if current_stage != 'Intake':
                cur.execute("INSERT INTO triage_events (so_id, inspector_id, findings) VALUES (%s, %s, %s)",
                            (so_id, random.choice(user_ids), fake.text()))

            # Simulate Compliance Check for Dispatched/Ready items
            if current_stage in ['Ready_to_Dispatch', 'Dispatched']:
                cur.execute("INSERT INTO compliance_checks (so_id, qa_manager_id, is_passed, electronic_signature_hash) VALUES (%s, %s, %s, %s)",
                            (so_id, random.choice(user_ids), True, fake.sha256()))

        conn.commit()
        print("Successfully populated 1,000 records. Ready for Fabric Analytics!")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            cur.close()
            conn.close()

if __name__ == "__main__":
    populate_data()
