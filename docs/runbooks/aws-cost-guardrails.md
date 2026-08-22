# Runbook — AWS cost guardrails (Budgets, billing alarm, Cost Explorer)

Context: this account runs on a one-time $100 Free Tier credit (see ADR-0003), not an ongoing budget. The guardrails below are belt-and-braces on purpose — three independent tripwires, so a mistake in one doesn't mean nothing catches an unexpected bill. Fill in the "Configured" lines below once each step is actually done, so this file becomes the single place to check "what's watching my spend and where."

## 1. A cost budget for the whole credit (the main guardrail)

This tracks total spend against the $100 credit directly, over the ~6-month window the Free Plan lasts, rather than an arbitrary monthly figure.

**Steps:**
1. Console → Billing and Cost Management → **Budgets** → **Create budget**.
2. **Customize (advanced)** → Budget type: **Cost budget** → Next.
3. Budget name: `gitpulse-free-tier-credit`.
4. Period: **Custom**. Renewal type: **Expiring budget**. Start: today. End: 6 months from today (check your AWS account's actual Free Plan expiry date in Billing → Free Tier if it's shown there, and match this to it).
5. Budgeting method: **Fixed**. Budgeted amount: **$80** — deliberately under the $100 credit, so the buffer itself is an early warning, not the full amount.
6. Add alert thresholds (add three, one at a time): 50% (**Actual**), 80% (**Actual**), 100% (**Forecasted** — this one warns before you even reach the earlier thresholds, if AWS's forecast says you're on track to).
7. Notification preferences → Email recipients: your email address, on every threshold.
8. Review → **Create budget**.

**Configured:** _(fill in once done)_ Name: `____`. Created: `____`. End date: `____`.

## 2. A monthly cost budget (catches one bad month early)

The credit budget above only warns as the *total* climbs — a single expensive month (e.g. an accidentally-left-running EKS cluster during a Phase 4 burst) could still do real damage before that trips. This is a smaller, independent tripwire scoped to just one month at a time.

**Steps:** Same flow as above, but: Budget name `gitpulse-monthly`, Period **Monthly**, Renewal type **Recurring budget**, Budgeting method **Fixed**, amount **$15**. Same three alert thresholds (50%/80%/100%), same email.

**Configured:** _(fill in once done)_ Amount: `____`.

## 3. A CloudWatch billing alarm (a blunt, independent backstop)

This exists in case Budgets itself is ever misconfigured or silently fails to notify — a second system watching the same thing, built differently.

**Steps:**
1. Console → Billing and Cost Management → **Billing preferences** → **Alert preferences** → tick **Receive CloudWatch Billing Alerts** → Save. Wait ~15 minutes for billing data to populate.
2. Switch the console region to **US East (N. Virginia)** — billing metrics only exist there, regardless of which region your actual resources run in.
3. CloudWatch console → **Alarms** → **All alarms** → **Create alarm**.
4. Select metric → **Billing** → **Total Estimated Charge** → the `EstimatedCharges` metric.
5. Statistic: **Maximum**. Period: **6 hours**. Condition: **Static**, **Greater than $20**.
6. Notification: create/select an SNS topic with your email as a subscriber.
7. Name it `gitpulse-billing-alarm` → Create alarm. Check your email for the SNS subscription confirmation link — the alarm won't actually notify you until that's confirmed.

**Configured:** _(fill in once done)_ Threshold: `____`. SNS topic: `____`.

## 4. Cost Explorer (for understanding *what* is costing money, not just *how much*)

Budgets and the alarm tell you *that* spend is happening. Cost Explorer is where you actually see *which service or resource* is responsible — this is the answer to "why is my bill what it is."

**Steps to enable (one-time):** Console → Billing and Cost Management → **Cost Explorer** → **Launch Cost Explorer**. Current-month data appears within ~24 hours; full history takes a few days to populate.

**How to use it when something looks off:** open Cost Explorer, and use the grouping/filter controls above the graph to group costs **by Service** first — that alone usually identifies the culprit (e.g. "EC2" or "EKS" spiking on a specific day). Group **by Region** next if the service alone doesn't explain it, since a resource left running in the wrong region is a common surprise.

**One gap worth knowing about:** enabling Cost Explorer also turns on **Cost Anomaly Detection**, with a default monitor that only alerts once anomalous spend exceeds **both** $100 and 40% of expected spend. On a $100-total account, that default could trigger only once the entire credit is already at risk. Worth tightening: Billing console → **Cost Anomaly Detection** → edit the default monitor's alert threshold down to something like $10–15, rather than leaving AWS's default.

## Where to look, day to day

- **"Is anything about to breach budget?"** → Budgets page, both budgets above.
- **"What's actually running up cost right now?"** → Cost Explorer, grouped by Service.
- **"Did an alarm actually fire?"** → CloudWatch → Alarms, and your email inbox (both the SNS subscription confirmation and any subsequent alerts land there).
