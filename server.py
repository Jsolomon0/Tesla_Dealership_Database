from flask import Flask, render_template, request, redirect, url_for
from sqlalchemy import create_engine, text
import os

app = Flask(__name__)

DB_URI = os.environ.get('DATABASE_URI', 'postgresql://USERNAME:PASSWORD@localhost:5432/tesla_db')
engine = create_engine(DB_URI, future=True)


def fetch_all(sql, params=None):
    with engine.connect() as conn:
        result = conn.execute(text(sql), params or {})
        return result.fetchall()


def fetch_one(sql, params=None):
    with engine.connect() as conn:
        result = conn.execute(text(sql), params or {})
        return result.fetchone()


def execute(sql, params=None):
    with engine.begin() as conn:
        conn.execute(text(sql), params or {})


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/vehicles')
def vehicles():
    models = fetch_all('SELECT model_id, model_name FROM models ORDER BY model_name')
    dealerships = fetch_all('SELECT dealership_id, name FROM dealerships ORDER BY name')

    model_id = request.args.get('model_id')
    dealership_id = request.args.get('dealership_id')
    available_only = request.args.get('available_only') == 'on'

    conditions = []
    params = {}
    if model_id:
        conditions.append('v.model_id = :model_id')
        params['model_id'] = int(model_id)
    if dealership_id:
        conditions.append('v.dealership_id = :dealership_id')
        params['dealership_id'] = int(dealership_id)
    if available_only:
        conditions.append('v.available = TRUE')

    where_sql = ('WHERE ' + ' AND '.join(conditions)) if conditions else ''

    rows = fetch_all(f'''
        SELECT v.vin, m.model_name, v.model_year, v.color, v.mileage, v.price, v.available, d.name AS dealership
        FROM vehicles v
        JOIN models m ON v.model_id = m.model_id
        JOIN dealerships d ON v.dealership_id = d.dealership_id
        {where_sql}
        ORDER BY v.price ASC
    ''', params)

    return render_template('vehicles.html', rows=rows, models=models, dealerships=dealerships,
                           selected_model=model_id, selected_dealership=dealership_id,
                           available_only=available_only)


@app.route('/vehicles/<vin>')
def vehicle_detail(vin):
    vehicle = fetch_one('''
        SELECT v.vin, m.model_name, v.model_year, v.color, v.mileage, v.price, v.available, v.features,
               d.name AS dealership, d.city, d.state
        FROM vehicles v
        JOIN models m ON v.model_id = m.model_id
        JOIN dealerships d ON v.dealership_id = d.dealership_id
        WHERE v.vin = :vin
    ''', {'vin': vin})

    reviews = fetch_all('''
        SELECT r.review_id, c.full_name, r.rating, r.review_text, r.review_date
        FROM reviews r
        JOIN customers c ON r.customer_id = c.customer_id
        WHERE r.vin = :vin
        ORDER BY r.review_date DESC
    ''', {'vin': vin})

    services = fetch_all('''
        SELECT s.service_id, s.service_date, s.service_type
        FROM service_appointments s
        WHERE s.vin = :vin
        ORDER BY s.service_date DESC
    ''', {'vin': vin})

    return render_template('vehicle.html', vehicle=vehicle, reviews=reviews, services=services)


@app.route('/reviews/add', methods=['GET', 'POST'])
def add_review():
    customers = fetch_all('SELECT customer_id, full_name FROM customers ORDER BY full_name')
    vehicles_list = fetch_all('SELECT vin FROM vehicles ORDER BY vin')

    if request.method == 'POST':
        params = {
            'customer_id': int(request.form['customer_id']),
            'vin': request.form['vin'],
            'rating': int(request.form['rating']),
            'review_text': request.form['review_text'],
            'review_date': request.form['review_date']
        }
        execute('''
            INSERT INTO reviews (customer_id, vin, rating, review_text, review_date)
            VALUES (:customer_id, :vin, :rating, :review_text, :review_date)
        ''', params)
        return redirect(url_for('vehicle_detail', vin=params['vin']))

    return render_template('add_review.html', customers=customers, vehicles=vehicles_list)


@app.route('/sales/add', methods=['GET', 'POST'])
def add_sale():
    customers = fetch_all('SELECT customer_id, full_name FROM customers ORDER BY full_name')
    employees = fetch_all('SELECT employee_id, full_name FROM employees ORDER BY full_name')
    vehicles_list = fetch_all('SELECT vin FROM vehicles WHERE available = TRUE ORDER BY vin')

    if request.method == 'POST':
        params = {
            'vin': request.form['vin'],
            'customer_id': int(request.form['customer_id']),
            'employee_id': int(request.form['employee_id']),
            'sale_date': request.form['sale_date'],
            'sale_price': request.form['sale_price']
        }
        execute('''
            INSERT INTO sales (vin, customer_id, employee_id, sale_date, sale_price)
            VALUES (:vin, :customer_id, :employee_id, :sale_date, :sale_price)
        ''', params)
        return redirect(url_for('sales'))

    return render_template('add_sale.html', customers=customers, employees=employees, vehicles=vehicles_list)


@app.route('/services/add', methods=['GET', 'POST'])
def add_service():
    customers = fetch_all('SELECT customer_id, full_name FROM customers ORDER BY full_name')
    vehicles_list = fetch_all('SELECT vin FROM vehicles ORDER BY vin')

    if request.method == 'POST':
        params = {
            'vin': request.form['vin'],
            'customer_id': int(request.form['customer_id']),
            'service_date': request.form['service_date'],
            'service_type': request.form['service_type']
        }
        execute('''
            INSERT INTO service_appointments (vin, customer_id, service_date, service_type)
            VALUES (:vin, :customer_id, :service_date, :service_type)
        ''', params)
        return redirect(url_for('vehicle_detail', vin=params['vin']))

    return render_template('add_service.html', customers=customers, vehicles=vehicles_list)


@app.route('/sales')
def sales():
    rows = fetch_all('''
        SELECT s.sale_id, s.sale_date, s.sale_price, v.vin, m.model_name,
               c.full_name AS customer, e.full_name AS employee
        FROM sales s
        JOIN vehicles v ON s.vin = v.vin
        JOIN models m ON v.model_id = m.model_id
        JOIN customers c ON s.customer_id = c.customer_id
        JOIN employees e ON s.employee_id = e.employee_id
        ORDER BY s.sale_date DESC
    ''')
    return render_template('sales.html', rows=rows)


@app.route('/financing')
def financing():
    lenders = fetch_all('SELECT lender_id, name, phone FROM lenders ORDER BY name')
    plans = fetch_all('''
        SELECT fp.plan_id, fp.plan_name, fp.apr, fp.term_months, fp.min_down_payment,
               l.name AS lender
        FROM financing_plans fp
        JOIN lenders l ON fp.lender_id = l.lender_id
        ORDER BY l.name, fp.plan_name
    ''')
    return render_template('financing.html', lenders=lenders, plans=plans)


@app.route('/loans')
def loans():
    rows = fetch_all('''
        SELECT lo.loan_id, lo.sale_id, lo.principal, lo.down_payment, lo.start_date, lo.status,
               fp.plan_name, l.name AS lender
        FROM loans lo
        JOIN financing_plans fp ON lo.plan_id = fp.plan_id
        JOIN lenders l ON fp.lender_id = l.lender_id
        ORDER BY lo.start_date DESC
    ''')
    return render_template('loans.html', rows=rows)


@app.route('/loans/add', methods=['GET', 'POST'])
def add_loan():
    sales_list = fetch_all('SELECT sale_id FROM sales ORDER BY sale_id')
    plans = fetch_all('''
        SELECT fp.plan_id, fp.plan_name, l.name AS lender
        FROM financing_plans fp
        JOIN lenders l ON fp.lender_id = l.lender_id
        ORDER BY l.name, fp.plan_name
    ''')
    if request.method == 'POST':
        params = {
            'sale_id': int(request.form['sale_id']),
            'plan_id': int(request.form['plan_id']),
            'principal': request.form['principal'],
            'down_payment': request.form['down_payment'],
            'start_date': request.form['start_date'],
            'status': request.form['status']
        }
        execute('''
            INSERT INTO loans (sale_id, plan_id, principal, down_payment, start_date, status)
            VALUES (:sale_id, :plan_id, :principal, :down_payment, :start_date, :status)
        ''', params)
        return redirect(url_for('loans'))
    return render_template('add_loan.html', sales=sales_list, plans=plans)


@app.route('/trade-ins')
def trade_ins():
    rows = fetch_all('''
        SELECT trade_in_id, sale_id, vin, make, model, model_year, mileage, allowance
        FROM trade_ins
        ORDER BY trade_in_id DESC
    ''')
    return render_template('trade_ins.html', rows=rows)


@app.route('/trade-ins/add', methods=['GET', 'POST'])
def add_trade_in():
    sales_list = fetch_all('SELECT sale_id FROM sales ORDER BY sale_id')
    if request.method == 'POST':
        params = {
            'sale_id': int(request.form['sale_id']),
            'vin': request.form['vin'] or None,
            'make': request.form['make'],
            'model': request.form['model'],
            'model_year': request.form['model_year'],
            'mileage': request.form['mileage'],
            'allowance': request.form['allowance']
        }
        execute('''
            INSERT INTO trade_ins (sale_id, vin, make, model, model_year, mileage, allowance)
            VALUES (:sale_id, :vin, :make, :model, :model_year, :mileage, :allowance)
        ''', params)
        return redirect(url_for('trade_ins'))
    return render_template('add_trade_in.html', sales=sales_list)


@app.route('/transfers')
def transfers():
    rows = fetch_all('''
        SELECT it.transfer_id, it.vin, it.transfer_date, it.status,
               d_from.name AS from_dealership, d_to.name AS to_dealership
        FROM inventory_transfers it
        JOIN dealerships d_from ON it.from_dealership_id = d_from.dealership_id
        JOIN dealerships d_to ON it.to_dealership_id = d_to.dealership_id
        ORDER BY it.transfer_date DESC
    ''')
    return render_template('transfers.html', rows=rows)


@app.route('/transfers/add', methods=['GET', 'POST'])
def add_transfer():
    vehicles_list = fetch_all('SELECT vin FROM vehicles ORDER BY vin')
    dealerships = fetch_all('SELECT dealership_id, name FROM dealerships ORDER BY name')
    if request.method == 'POST':
        params = {
            'vin': request.form['vin'],
            'from_dealership_id': int(request.form['from_dealership_id']),
            'to_dealership_id': int(request.form['to_dealership_id']),
            'transfer_date': request.form['transfer_date'],
            'status': request.form['status']
        }
        execute('''
            INSERT INTO inventory_transfers (vin, from_dealership_id, to_dealership_id, transfer_date, status)
            VALUES (:vin, :from_dealership_id, :to_dealership_id, :transfer_date, :status)
        ''', params)
        return redirect(url_for('transfers'))
    return render_template('add_transfer.html', vehicles=vehicles_list, dealerships=dealerships)


@app.route('/service-invoices')
def service_invoices():
    invoices = fetch_all('''
        SELECT si.invoice_id, si.total_amount, si.paid,
               sa.service_date, sa.service_type, sa.vin
        FROM service_invoices si
        JOIN service_appointments sa ON si.service_id = sa.service_id
        ORDER BY sa.service_date DESC
    ''')
    items = fetch_all('''
        SELECT item_id, invoice_id, description, labor_hours, part_cost, labor_rate
        FROM service_items
        ORDER BY item_id DESC
    ''')
    return render_template('service_invoices.html', invoices=invoices, items=items)


@app.route('/service-items/add', methods=['GET', 'POST'])
def add_service_item():
    invoices = fetch_all('SELECT invoice_id FROM service_invoices ORDER BY invoice_id')
    if request.method == 'POST':
        params = {
            'invoice_id': int(request.form['invoice_id']),
            'description': request.form['description'],
            'labor_hours': request.form['labor_hours'],
            'part_cost': request.form['part_cost'],
            'labor_rate': request.form['labor_rate']
        }
        execute('''
            INSERT INTO service_items (invoice_id, description, labor_hours, part_cost, labor_rate)
            VALUES (:invoice_id, :description, :labor_hours, :part_cost, :labor_rate)
        ''', params)
        return redirect(url_for('service_invoices'))
    return render_template('add_service_item.html', invoices=invoices)


if __name__ == '__main__':
    app.run(debug=True)
