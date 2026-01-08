import pytest

# Scenario Logic Simulations

def check_budget_feasibility(total_cost, budget):
    return total_cost <= budget

def check_capacity_target(installed_capacity_kw, target_kw):
    return installed_capacity_kw >= target_kw

def select_best_panels(panels_list, budget):
    """
    Selects the most powerful panel that fits within budget (Mock logic)
    """
    candidates = [p for p in panels_list if p['cost'] <= budget]
    if not candidates:
        return None
    # Sort by power descending
    candidates.sort(key=lambda x: x['power'], reverse=True)
    return candidates[0]

# --- Tests ---

def test_budget_within_limits():
    """
    Cost: 40,000. Budget: 50,000. Should Pass.
    """
    assert check_budget_feasibility(40000, 50000) is True

def test_budget_exceeded():
    """
    Cost: 60,000. Budget: 50,000. Should Fail.
    """
    assert check_budget_feasibility(60000, 50000) is False

def test_budget_exact_match():
    """
    Cost: 50,000. Budget: 50,000. Should Pass (inclusive).
    """
    assert check_budget_feasibility(50000, 50000) is True

def test_capacity_target_met():
    """
    Installed: 12 kW. Target: 10 kW. Success.
    """
    assert check_capacity_target(12, 10) is True

def test_capacity_target_failed():
    """
    Installed: 8 kW. Target: 10 kW. Fail.
    """
    assert check_capacity_target(8, 10) is False

def test_best_panel_selection():
    """
    Given a list of panels and a budget for a single unit (simplified), pick best.
    """
    panels = [
        {'name': 'Cheap', 'cost': 100, 'power': 200},
        {'name': 'Mid', 'cost': 200, 'power': 300},
        {'name': 'Expensive', 'cost': 500, 'power': 450}
    ]
    budget = 250
    # Should pick 'Mid' (Cost 200 <= 250, Power 300 > 200)
    # Expensive (500) is out of budget.
    
    selected = select_best_panels(panels, budget)
    assert selected['name'] == 'Mid'

def test_best_panel_no_option():
    """
    Budget too low for any panel.
    """
    panels = [{'name': 'Min', 'cost': 100, 'power': 200}]
    budget = 50
    selected = select_best_panels(panels, budget)
    assert selected is None

def test_scenario_mixed_equipment():
    """
    Test logic for summing costs of mixed items.
    """
    items = [
        {'type': 'Solar', 'cost': 1000},
        {'type': 'Wind', 'cost': 2000},
        {'type': 'Battery', 'cost': 500}
    ]
    total = sum(item['cost'] for item in items)
    assert total == 3500
