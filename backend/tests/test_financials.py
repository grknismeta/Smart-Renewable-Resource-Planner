import pytest

# Mock Financial Logic Functions (to be implemented in services later, or tested here as proof of concept)
# In a real app, these would undergo the same "Service vs Logic" separation.
# For now, we define the logic here to verify the mathematical correctness before we even write the service!
# This is "Test Driven Development" (TDD).

def calculate_simple_payback(investment_cost, annual_savings):
    if annual_savings <= 0:
        return float('inf')
    return investment_cost / annual_savings

def calculate_roi(investment_cost, total_net_profit):
    if investment_cost == 0:
        return 0.0
    return (total_net_profit / investment_cost) * 100.0

def calculate_npv(rate, cash_flows):
    # Net Present Value = Sum ( CashFlow_t / (1+r)^t )
    npv = 0.0
    for t, cash in enumerate(cash_flows):
        npv += cash / ((1 + rate) ** t)
    return npv

# --- Tests ---

def test_payback_period_standard():
    """
    If I spend $10,000 and save $2,000/year, payback is 5 years.
    """
    cost = 10000.0
    savings = 2000.0
    period = calculate_simple_payback(cost, savings)
    assert period == 5.0

def test_payback_period_zero_savings():
    """
    If I save nothing, I never pay back (Infinite).
    """
    cost = 1000.0
    savings = 0.0
    period = calculate_simple_payback(cost, savings)
    assert period == float('inf')

def test_roi_calculation():
    """
    Cost: 1000, Total Gain (Lifetime): 1500.
    Net Profit: 500.
    ROI = (500/1000) * 100 = 50%.
    """
    cost = 1000.0
    net_profit = 500.0
    roi = calculate_roi(cost, net_profit)
    assert roi == 50.0

def test_roi_zero_investment():
    """
    If cost is 0, ROI technically undefined or handled gracefully.
    Let's simple say 0 for this logic to avoid Div/0 error.
    """
    roi = calculate_roi(0, 100)
    assert roi == 0.0

def test_npv_profitable_project():
    """
    Year 0: -100 (Investment)
    Year 1: 110 (Return)
    Rate: 10% (0.10)
    
    NPV = -100/(1.1)^0 + 110/(1.1)^1
        = -100 + 100 
        = 0
    (Break even NPV)
    """
    rate = 0.10
    flows = [-100.0, 110.0]
    npv = calculate_npv(rate, flows)
    assert abs(npv) < 0.01

def test_npv_loss_project():
    """
    Year 0: -100
    Year 1: 50
    Rate: 10%
    NPV = -100 + 50/1.1 = -100 + 45.45 = -54.55
    """
    rate = 0.10
    flows = [-100.0, 50.0]
    npv = calculate_npv(rate, flows)
    assert npv < 0 # Should be negative

def test_lcoe_simplified():
    """
    Levelized Cost of Energy (LCOE) = Total Cost / Total Energy Produced
    Cost: $100,000
    Energy: 2,000,000 kWh
    LCOE = 0.05 $/kWh
    """
    total_cost = 100000.0
    total_energy = 2000000.0
    lcoe = total_cost / total_energy
    assert lcoe == 0.05

def test_depreciation_linear():
    """
    Linear Depreciation.
    Value: 10,000. Lifespan: 10 years.
    Depreciation per year: 1,000.
    Value at Year 3: 10,000 - 3000 = 7000.
    """
    initial_value = 10000.0
    lifespan = 10
    year = 3
    
    depreciation_per_year = initial_value / lifespan
    current_value = initial_value - (depreciation_per_year * year)
    
    assert current_value == 7000.0
