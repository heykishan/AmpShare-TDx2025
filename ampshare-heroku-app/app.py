from flask import Flask, jsonify, request
import os
import psycopg2
import uuid
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

# Helper function to get database connection
def get_db_connection():
    DATABASE_URL = os.environ.get('DATABASE_URL')
    conn = psycopg2.connect(DATABASE_URL)
    return conn

@app.route('/')
def home():
    return "Welcome to AmpShare API"

@app.route('/api/value', methods=['GET'])
def get_value():
    return jsonify({"value": 10})

# UPSERT endpoint for accounts
@app.route('/api/accounts/upsert', methods=['POST'])
def upsert_account():
    try:
        # Get data from request
        data = request.json
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided"
            }), 400
        
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Check if salesforce_id is provided (required for upsert)
        if 'salesforce_id' not in data or not data['salesforce_id']:
            conn.close()
            return jsonify({
                "success": False,
                "error": "salesforce_id is required for upsert operation"
            }), 400
        
        # Check if account with this Salesforce ID already exists
        cursor.execute("SELECT id FROM AmpShare.account WHERE salesforce_id = %s AND isDeleted = false", 
                      (data['salesforce_id'],))
        existing_account = cursor.fetchone()
        
        field_mapping = {
            'first_name': 'account_first_name',
            'last_name': 'account_last_name',
            'suffix': 'account_suffix',
            'salutation': 'salutation',
            'email': 'email',
            'mobile': 'mobile',
            'alternate_phone': 'alternate_phone',
            'account_type': 'account_type',
            'whatsapp_number': 'whatsapp_number',
            'last_charged_vehicle': 'last_charged_vehicle',
            'salesforce_id': 'salesforce_id',
            'org_id': 'org_id'
        }
        
        if existing_account:
            # UPDATE existing account
            account_id = existing_account['id']
            
            set_clause = []
            values = []
            
            for key, value in data.items():
                if key in field_mapping:
                    set_clause.append(f"{field_mapping[key]} = %s")
                    values.append(value)
            
            if not set_clause:
                conn.close()
                return jsonify({
                    "success": False,
                    "error": "No valid fields to update"
                }), 400
            
            # Add account_id to values
            values.append(account_id)
            
            # Create the SQL statement
            sql = f"UPDATE AmpShare.account SET {', '.join(set_clause)} WHERE id = %s RETURNING *"
            
            # Execute the query
            cursor.execute(sql, values)
            updated_account = cursor.fetchone()
            
            # Commit the transaction
            conn.commit()
            
            # Return success response
            return jsonify({
                "success": True,
                "operation": "update",
                "account": dict(updated_account),
                "message": "Account updated successfully"
            })
            
        else:
            # INSERT new account
            # Generate a UUID for the id field
            new_id = str(uuid.uuid4()).replace('-', '')[:30]
            
            # Build the SQL query dynamically based on provided fields
            fields = ['id']
            values = [new_id]
            placeholders = ['%s']
            
            for key, value in data.items():
                if key in field_mapping and value is not None:
                    fields.append(field_mapping[key])
                    values.append(value)
                    placeholders.append('%s')
            
            # Create the SQL statement
            sql = f"INSERT INTO AmpShare.account ({', '.join(fields)}) VALUES ({', '.join(placeholders)}) RETURNING *"
            
            # Execute the query
            cursor.execute(sql, values)
            new_account = cursor.fetchone()
            
            # Commit the transaction
            conn.commit()
            
            # Return success response
            return jsonify({
                "success": True,
                "operation": "insert",
                "account": dict(new_account),
                "message": "Account created successfully"
            }), 201
            
    except Exception as e:
        # If any error occurs, rollback the transaction
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# UPSERT endpoint for chargers
@app.route('/api/chargers/upsert', methods=['POST'])
def upsert_charger():
    try:
        # Get data from request
        data = request.json
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided"
            }), 400
        
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Check if salesforce_id is provided (required for upsert)
        if 'salesforce_id' not in data or not data['salesforce_id']:
            conn.close()
            return jsonify({
                "success": False,
                "error": "salesforce_id is required for upsert operation"
            }), 400
        
        # Check if charger with this Salesforce ID already exists
        cursor.execute("SELECT id FROM AmpShare.charger WHERE salesforce_id = %s AND isDeleted = false", 
                      (data['salesforce_id'],))
        existing_charger = cursor.fetchone()
        
        field_mapping = {
            'charger_brand': 'charger_brand',
            'charger_model': 'charger_model',
            'charger_variant': 'charger_variant',
            'charger_model_year': 'charger_model_year',
            'charger_serial_number': 'charger_serial_number',
            'type': 'type',
            'power': 'power',
            'address_latitude': 'address_latitude',
            'full_address': 'full_address',
            'street_address_1': 'street_address_1',
            'street_address_2': 'street_address_2',
            'city': 'city',
            'country': 'country',
            'postcode': 'postcode',
            'is_available': 'is_available',
            'account_reference_id': 'account_reference_id',
            'salesforce_id': 'salesforce_id',
            'org_id': 'org_id'
        }
        
        if existing_charger:
            # UPDATE existing charger
            charger_id = existing_charger['id']
            
            set_clause = []
            values = []
            
            for key, value in data.items():
                if key in field_mapping:
                    set_clause.append(f"{field_mapping[key]} = %s")
                    values.append(value)
            
            if not set_clause:
                conn.close()
                return jsonify({
                    "success": False,
                    "error": "No valid fields to update"
                }), 400
            
            # Add charger_id to values
            values.append(charger_id)
            
            # Create the SQL statement
            sql = f"UPDATE AmpShare.charger SET {', '.join(set_clause)} WHERE id = %s RETURNING *"
            
            # Execute the query
            cursor.execute(sql, values)
            updated_charger = cursor.fetchone()
            
            # Commit the transaction
            conn.commit()
            
            # Return success response
            return jsonify({
                "success": True,
                "operation": "update",
                "charger": dict(updated_charger),
                "message": "Charger updated successfully"
            })
            
        else:
            # INSERT new charger
            # Generate a UUID for the id field
            new_id = str(uuid.uuid4()).replace('-', '')[:30]
            
            # Build the SQL query dynamically based on provided fields
            fields = ['id']
            values = [new_id]
            placeholders = ['%s']
            
            for key, value in data.items():
                if key in field_mapping and value is not None:
                    fields.append(field_mapping[key])
                    values.append(value)
                    placeholders.append('%s')
            
            # Create the SQL statement
            sql = f"INSERT INTO AmpShare.charger ({', '.join(fields)}) VALUES ({', '.join(placeholders)}) RETURNING *"
            
            # Execute the query
            cursor.execute(sql, values)
            new_charger = cursor.fetchone()
            
            # Commit the transaction
            conn.commit()
            
            # Return success response
            return jsonify({
                "success": True,
                "operation": "insert",
                "charger": dict(new_charger),
                "message": "Charger created successfully"
            }), 201
            
    except Exception as e:
        # If any error occurs, rollback the transaction
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# SOFT DELETE endpoint for accounts
@app.route('/api/accounts/delete/<id_type>/<account_id>', methods=['POST'])
def soft_delete_account(id_type, account_id):
    try:
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Find account based on id_type
        if id_type == 'id':
            # Delete by primary key
            cursor.execute("SELECT id FROM AmpShare.account WHERE id = %s AND isDeleted = false", (account_id,))
        elif id_type == 'salesforce':
            # Delete by Salesforce ID
            cursor.execute("SELECT id FROM AmpShare.account WHERE salesforce_id = %s AND isDeleted = false", (account_id,))
        else:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Invalid ID type. Use 'id' or 'salesforce'"
            }), 400
        
        account = cursor.fetchone()
        
        if not account:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Account not found or already deleted"
            }), 404
        
        # Soft delete the account by setting isDeleted to true
        cursor.execute(
            "UPDATE AmpShare.account SET isDeleted = true WHERE id = %s RETURNING id, salesforce_id", 
            (account['id'],)
        )
        deleted_account = cursor.fetchone()
        
        # Commit the transaction
        conn.commit()
        
        # Return success response
        return jsonify({
            "success": True,
            "account": dict(deleted_account),
            "message": "Account soft deleted successfully"
        })
        
    except Exception as e:
        # If any error occurs, rollback the transaction
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# SOFT DELETE endpoint for chargers
@app.route('/api/chargers/delete/<id_type>/<charger_id>', methods=['POST'])
def soft_delete_charger(id_type, charger_id):
    try:
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Find charger based on id_type
        if id_type == 'id':
            # Delete by primary key
            cursor.execute("SELECT id FROM AmpShare.charger WHERE id = %s AND isDeleted = false", (charger_id,))
        elif id_type == 'salesforce':
            # Delete by Salesforce ID
            cursor.execute("SELECT id FROM AmpShare.charger WHERE salesforce_id = %s AND isDeleted = false", (charger_id,))
        else:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Invalid ID type. Use 'id' or 'salesforce'"
            }), 400
        
        charger = cursor.fetchone()
        
        if not charger:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Charger not found or already deleted"
            }), 404
        
        # Soft delete the charger by setting isDeleted to true
        cursor.execute(
            "UPDATE AmpShare.charger SET isDeleted = true WHERE id = %s RETURNING id, salesforce_id", 
            (charger['id'],)
        )
        deleted_charger = cursor.fetchone()
        
        # Commit the transaction
        conn.commit()
        
        # Return success response
        return jsonify({
            "success": True,
            "charger": dict(deleted_charger),
            "message": "Charger soft deleted successfully"
        })
        
    except Exception as e:
        # If any error occurs, rollback the transaction
        if 'conn' in locals() and conn:
            conn.rollback()
            conn.close()
        
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# Get account by ID or Salesforce ID
@app.route('/api/accounts/<id_type>/<account_id>', methods=['GET'])
def get_account(id_type, account_id):
    try:
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if id_type == 'id':
            # Get by primary key
            cursor.execute("SELECT * FROM AmpShare.account WHERE id = %s AND isDeleted = false", (account_id,))
        elif id_type == 'salesforce':
            # Get by Salesforce ID
            cursor.execute("SELECT * FROM AmpShare.account WHERE salesforce_id = %s AND isDeleted = false", (account_id,))
        else:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Invalid ID type. Use 'id' or 'salesforce'"
            }), 400
        
        account = cursor.fetchone()
        
        if not account:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Account not found"
            }), 404
        
        # Return the account
        return jsonify({
            "success": True,
            "account": dict(account)
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# Get charger by ID or Salesforce ID
@app.route('/api/chargers/<id_type>/<charger_id>', methods=['GET'])
def get_charger(id_type, charger_id):
    try:
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if id_type == 'id':
            # Get by primary key
            cursor.execute("SELECT * FROM AmpShare.charger WHERE id = %s AND isDeleted = false", (charger_id,))
        elif id_type == 'salesforce':
            # Get by Salesforce ID
            cursor.execute("SELECT * FROM AmpShare.charger WHERE salesforce_id = %s AND isDeleted = false", (charger_id,))
        else:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Invalid ID type. Use 'id' or 'salesforce'"
            }), 400
        
        charger = cursor.fetchone()
        
        if not charger:
            conn.close()
            return jsonify({
                "success": False,
                "error": "Charger not found"
            }), 404
        
        # Return the charger
        return jsonify({
            "success": True,
            "charger": dict(charger)
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# Get all accounts (with optional filters)
@app.route('/api/accounts', methods=['GET'])
def get_accounts():
    try:
        # Get query parameters
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        org_id = request.args.get('org_id')
        
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Build query based on filters
        query = "SELECT * FROM AmpShare.account WHERE isDeleted = false"
        params = []
        
        if org_id:
            query += " AND org_id = %s"
            params.append(org_id)
        
        query += " LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        # Execute the query
        cursor.execute(query, params)
        accounts = cursor.fetchall()
        
        # Count total number of accounts for pagination
        count_query = "SELECT COUNT(*) FROM AmpShare.account WHERE isDeleted = false"
        if org_id:
            count_query += " AND org_id = %s"
            cursor.execute(count_query, [org_id])
        else:
            cursor.execute(count_query)
        
        total_count = cursor.fetchone()['count']
        
        # Return the accounts
        return jsonify({
            "success": True,
            "total": total_count,
            "offset": offset,
            "limit": limit,
            "accounts": [dict(account) for account in accounts]
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

# Get all chargers (with optional filters)
@app.route('/api/chargers', methods=['GET'])
def get_chargers():
    try:
        # Get query parameters
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        org_id = request.args.get('org_id')
        account_id = request.args.get('account_id')
        
        # Connect to PostgreSQL
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Build query based on filters
        query = "SELECT * FROM AmpShare.charger WHERE isDeleted = false"
        params = []
        
        if org_id:
            query += " AND org_id = %s"
            params.append(org_id)
            
        if account_id:
            query += " AND account_reference_id = %s"
            params.append(account_id)
        
        query += " LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        # Execute the query
        cursor.execute(query, params)
        chargers = cursor.fetchall()
        
        # Count total number of chargers for pagination
        count_query = "SELECT COUNT(*) FROM AmpShare.charger WHERE isDeleted = false"
        count_params = []
        
        if org_id:
            count_query += " AND org_id = %s"
            count_params.append(org_id)
            
        if account_id:
            count_query += " AND account_reference_id = %s"
            count_params.append(account_id)
            
        cursor.execute(count_query, count_params)
        total_count = cursor.fetchone()['count']
        
        # Return the chargers
        return jsonify({
            "success": True,
            "total": total_count,
            "offset": offset,
            "limit": limit,
            "chargers": [dict(charger) for charger in chargers]
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
    
    finally:
        # Close the connection
        if 'conn' in locals() and conn:
            conn.close()

if __name__ == '__main__':
    app.run(debug=True)