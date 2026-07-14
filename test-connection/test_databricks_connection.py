#!/usr/bin/env python3
"""
Test Databricks connection and fetch billing data from system tables.

Usage (PAT token):
    python test_databricks_connection.py \
        --host https://xxx.cloud.databricks.com \
        --warehouse_id 64677bf6a6b7391d \
        --token <personal-access-token>

Usage (OAuth service principal):
    python test_databricks_connection.py \
        --host https://xxx.cloud.databricks.com \
        --warehouse_id 64677bf6a6b7391d \
        --client_id <oauth-client-id> \
        --client_secret <oauth-client-secret>

Requirements:
    pip install databricks-sdk
"""

import argparse
import csv
import sys
from datetime import datetime, timedelta, date

# SKU name → FOCUS ServiceCategory
def sku_to_service_category(sku_name):
    sku = sku_name.upper()
    if any(x in sku for x in ('SERVERLESS_SQL', 'SQL_COMPUTE', 'WAREHOUSE')):
        return 'Analytics'
    if 'STORAGE' in sku:
        return 'Storage'
    if any(x in sku for x in ('ML', 'MODEL_SERVING', 'AI_')):
        return 'AI and Machine Learning'
    if any(x in sku for x in ('ALL_PURPOSE', 'JOBS_COMPUTE', 'COMPUTE')):
        return 'Compute'
    return 'Compute'

FOCUS_COLUMNS = [
    'availability_zone', 'billing_account_id', 'billing_account_name',
    'billing_currency', 'billing_period_end', 'billing_period_start',
    'charge_category', 'charge_class', 'charge_description', 'charge_frequency',
    'charge_period_end', 'charge_period_start',
    'commitment_discount_category', 'commitment_discount_id',
    'commitment_discount_name', 'commitment_discount_status', 'commitment_discount_type',
    'consumed_unit', 'invoice_issuer_name', 'pricing_category', 'pricing_unit',
    'provider_name', 'publisher_name', 'region_id', 'region_name',
    'resource_id', 'resource_name', 'resource_type',
    'service_category', 'service_name', 'sku_id', 'sku_price_id',
    'sub_account_id', 'sub_account_name', 'tags', 'extension_version',
    'consumed_quantity', 'pricing_quantity',
    'contracted_unit_price', 'list_unit_price',
    'billed_cost', 'contracted_cost', 'effective_cost', 'list_cost',
]

def row_to_focus(row):
    usage_date_str  = row[0]                       # e.g. "2026-06-09"
    workspace_name  = row[1] or ''
    workspace_id    = row[2] or ''
    account_id      = row[3] or ''
    sku_name        = row[4] or ''
    usage_unit      = row[5] or ''
    total_quantity  = row[6] or '0'
    price_per_unit  = row[7] or '0'
    cost_usd        = row[8] or '0'

    d = datetime.strptime(str(usage_date_str), '%Y-%m-%d').date()
    period_start = d.strftime('%Y-%m-%dT00:00:00+00:00')
    period_end   = (d + timedelta(days=1)).strftime('%Y-%m-%dT00:00:00+00:00')
    bill_start   = d.replace(day=1).strftime('%Y-%m-%dT00:00:00+00:00')
    next_month   = (d.replace(day=1) + timedelta(days=32)).replace(day=1)
    bill_end     = next_month.strftime('%Y-%m-%dT00:00:00+00:00')

    return {
        'availability_zone':    '',
        'billing_account_id':   account_id,
        'billing_account_name': account_id,
        'billing_currency':     'USD',
        'billing_period_end':   bill_end,
        'billing_period_start': bill_start,
        'charge_category':      'Usage',
        'charge_class':         '',
        'charge_description':   sku_name,
        'charge_frequency':     'Usage-Based',
        'charge_period_end':    period_end,
        'charge_period_start':  period_start,
        'commitment_discount_category': '',
        'commitment_discount_id':       '',
        'commitment_discount_name':     '',
        'commitment_discount_status':   '',
        'commitment_discount_type':     '',
        'consumed_unit':        usage_unit,
        'invoice_issuer_name':  'Databricks',
        'pricing_category':     '',
        'pricing_unit':         usage_unit,
        'provider_name':        'Databricks',
        'publisher_name':       'Databricks',
        'region_id':            '',
        'region_name':          '',
        'resource_id':          '',
        'resource_name':        '',
        'resource_type':        '',
        'service_category':     sku_to_service_category(sku_name),
        'service_name':         sku_name,
        'sku_id':               sku_name,
        'sku_price_id':         '',
        'sub_account_id':       workspace_id,
        'sub_account_name':     workspace_name,
        'tags':                 '',
        'extension_version':    '',
        'consumed_quantity':    total_quantity,
        'pricing_quantity':     total_quantity,
        'contracted_unit_price': '',
        'list_unit_price':      price_per_unit,
        'billed_cost':          cost_usd,
        'contracted_cost':      '',
        'effective_cost':       cost_usd,
        'list_cost':            cost_usd,
    }

def write_focus_csv(rows, output_path):
    with open(output_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=FOCUS_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(row_to_focus(row))
    print(f"   Written {len(rows)} rows to {output_path}")

BILLING_QUERY = """
SELECT
    u.usage_date,
    w.workspace_name,
    u.workspace_id,
    u.account_id,
    u.sku_name,
    u.usage_unit,
    ROUND(SUM(u.usage_quantity), 6)                           AS total_quantity,
    MAX(p.pricing.default)                                    AS price_per_unit,
    ROUND(SUM(u.usage_quantity * p.pricing.default), 6)       AS cost_usd
FROM system.billing.usage u
LEFT JOIN system.billing.list_prices p
  ON u.sku_name = p.sku_name
 AND u.usage_date >= DATE(p.price_start_time)
 AND (p.price_end_time IS NULL OR u.usage_date < DATE(p.price_end_time))
LEFT JOIN system.access.workspaces_latest w
  ON u.workspace_id = CAST(w.workspace_id AS STRING)
WHERE u.usage_date >= DATEADD(day, -{days}, CURRENT_DATE())
GROUP BY
    u.usage_date, w.workspace_name, u.workspace_id, u.account_id,
    u.sku_name, u.usage_unit
ORDER BY u.usage_date DESC, cost_usd DESC
"""


def get_workspace_client(host, token=None, client_id=None, client_secret=None):
    from databricks.sdk import WorkspaceClient
    if token:
        return WorkspaceClient(host=host, token=token)
    elif client_id and client_secret:
        return WorkspaceClient(host=host, client_id=client_id, client_secret=client_secret)
    else:
        raise ValueError("Provide either --token or both --client_id and --client_secret")


def run_query(client, warehouse_id, sql):
    import time
    from databricks.sdk.service.sql import StatementState, Disposition

    response = client.statement_execution.execute_statement(
        warehouse_id=warehouse_id,
        statement=sql,
        wait_timeout="50s",
        disposition=Disposition.INLINE,
    )

    # Poll if still running after initial wait (e.g. warehouse was cold-starting)
    statement_id = response.statement_id
    for attempt in range(60):  # up to ~5 more minutes
        state = response.status.state
        if state == StatementState.SUCCEEDED:
            break
        if state in (StatementState.FAILED, StatementState.CANCELED, StatementState.CLOSED):
            raise RuntimeError(f"Query failed ({state}): {response.status.error}")
        print(f"   Waiting for query ({state.value}) ...")
        time.sleep(5)
        response = client.statement_execution.get_statement(statement_id)

    if response.status.state != StatementState.SUCCEEDED:
        raise RuntimeError(f"Query timed out ({response.status.state})")

    columns = [col.name for col in response.manifest.schema.columns]
    rows = response.result.data_array or []
    return columns, rows


def print_table(columns, rows):
    if not rows:
        print("   (no rows returned)")
        return
    widths = [max(len(str(col)), max((len(str(r[i] or '')) for r in rows), default=0))
              for i, col in enumerate(columns)]
    header = "  ".join(str(col).ljust(widths[i]) for i, col in enumerate(columns))
    print(f"   {header}")
    print(f"   {'-' * len(header)}")
    for row in rows:
        print("   " + "  ".join(str(v or '').ljust(widths[i]) for i, v in enumerate(row)))


def test_connection(host, warehouse_id, token=None, client_id=None, client_secret=None, days=1, billing_only=False, output=None):
    print("=" * 80)
    print("Testing Databricks Connection")
    print("=" * 80)

    # 1. Connect
    print(f"\n1. Connecting to {host} ...")
    try:
        client = get_workspace_client(host, token=token, client_id=client_id, client_secret=client_secret)
        me = client.current_user.me()
        print(f"   Connected as: {me.user_name}")
        print(f"   Display name: {me.display_name}")
    except Exception as e:
        print(f"   FAILED: {e}")
        return False

    # 2. Verify warehouse
    print(f"\n2. Checking SQL warehouse {warehouse_id} ...")
    try:
        warehouse = client.warehouses.get(warehouse_id)
        print(f"   Name:  {warehouse.name}")
        print(f"   Size:  {warehouse.cluster_size}")
        print(f"   State: {warehouse.state.value}")
    except Exception as e:
        print(f"   FAILED: {e}")
        return False

    # 3. Check each system table individually (skip with --billing-only)
    if billing_only:
        print(f"\n3. Skipping table checks (--billing-only)")
    else:
        tables = [
            ("system.billing.usage",            "SELECT COUNT(*) FROM system.billing.usage"),
            ("system.billing.list_prices",      "SELECT COUNT(*) FROM system.billing.list_prices"),
            ("system.access.workspaces_latest", "SELECT COUNT(*) FROM system.access.workspaces_latest"),
            ("system.compute.clusters",         "SELECT COUNT(*) FROM system.compute.clusters"),
            ("system.compute.warehouses",       "SELECT COUNT(*) FROM system.compute.warehouses"),
        ]
        print(f"\n3. Verifying access to each system table ...")
        for table_name, sql in tables:
            try:
                cols, rows = run_query(client, warehouse_id, sql)
                count = rows[0][0] if rows else '?'
                print(f"   OK  {table_name} ({count} rows)")
            except Exception as e:
                print(f"   FAIL {table_name}: {e}")
                return False

    # 4. Fetch billing data
    print(f"\n4. Fetching billing data (last {days} days) ...")
    try:
        sql = BILLING_QUERY.format(days=days)
        cols, rows = run_query(client, warehouse_id, sql)
        print(f"   Returned {len(rows)} rows\n")
        print_table(cols, rows)

        total_cost = sum(float(r[8] or 0) for r in rows)
        print(f"\n   Total cost (last {days} days): ${total_cost:.4f}")

        if output:
            print(f"\n5. Writing FOCUS CSV ...")
            write_focus_csv(rows, output)
    except Exception as e:
        print(f"   FAILED: {e}")
        return False

    print("\n" + "=" * 80)
    print("SUCCESS")
    print("=" * 80)
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Test Databricks connection and fetch billing data')
    parser.add_argument('--host',           required=True,  help='Workspace URL, e.g. https://xxx.cloud.databricks.com')
    parser.add_argument('--warehouse_id',   required=True,  help='SQL warehouse ID, e.g. 64677bf6a6b7391d')
    parser.add_argument('--token',          default=None,   help='Personal access token (for direct testing)')
    parser.add_argument('--client_id',      default=None,   help='OAuth service principal client ID')
    parser.add_argument('--client_secret',  default=None,   help='OAuth service principal client secret')
    parser.add_argument('--days',           default=1, type=int, help='Days of billing history to fetch (default: 1)')
    parser.add_argument('--billing-only',   action='store_true', help='Skip table checks, go straight to billing query')
    parser.add_argument('--output',         default=None,        help='Write FOCUS CSV to this file path (e.g. databricks_focus.csv)')
    args = parser.parse_args()

    success = test_connection(
        host=args.host,
        warehouse_id=args.warehouse_id,
        token=args.token,
        client_id=args.client_id,
        client_secret=args.client_secret,
        days=args.days,
        billing_only=args.billing_only,
        output=args.output,
    )
    sys.exit(0 if success else 1)
