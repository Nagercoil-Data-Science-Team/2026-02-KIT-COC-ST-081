clc;
clear;
close all;

fprintf('====================================================\n');
fprintf(' EGYPT PSH SYSTEM - COMPLETE OPTIMIZATION ANALYSIS\n');
fprintf('====================================================\n\n');

%% -----------------------------
% TIME SETUP
% -----------------------------
hours    = 1:24;
time_sec = (hours - 1) * 3600;

%% -----------------------------
% LOAD GENERATION (FORMULA-BASED)
% -----------------------------
Load = zeros(1,24);

% Night OFF-PEAK (12 AM – 6 AM)
Load(1:6) = 18000 + 500*sin(linspace(0,pi,6));

% Morning PEAK (6 AM – 11 AM)
Load(7:11) = 25500 + 7500*sin(linspace(0,pi,5));

% Midday OFF-PEAK (11 AM – 6 PM)
Load(12:17) = linspace(30500,18000,6);

% Evening PEAK (6 PM – 11 PM)
Load(18:23) = 24000 + 14000*sin(linspace(0,pi,6));

% Late Night OFF-PEAK
Load(24) = 24000;

Load = round(Load);

%% -----------------------------
% PEAK / OFF-PEAK IDENTIFICATION
% -----------------------------
Period = strings(1,24);
for h = 1:24
    if (h >= 7 && h <= 11) || (h >= 18 && h <= 23)
        Period(h) = "PEAK";
    else
        Period(h) = "OFF-PEAK";
    end
end

%% -----------------------------
% PEAK LOAD CHARACTERISTICS
% -----------------------------
Peak_Loads = Load(Period == "PEAK");
Peak_Hours = hours(Period == "PEAK");

Max_Peak_Load = max(Peak_Loads);
Avg_Peak_Load = mean(Peak_Loads);
Peak_Duration = length(Peak_Loads);

% Ramp Rate (MW/hour)
Ramp_Rate = [0 diff(Load)];

Max_Ramp_Up   = max(Ramp_Rate);
Max_Ramp_Down = min(Ramp_Rate);

fprintf('================ PEAK LOAD CHARACTERISTICS ================\n');
fprintf('Maximum Peak Load       : %d MW\n', Max_Peak_Load);
fprintf('Average Peak Load       : %.2f MW\n', Avg_Peak_Load);
fprintf('Total Peak Duration     : %d hours\n', Peak_Duration);
fprintf('Maximum Ramp-Up Rate    : %d MW/hour\n', Max_Ramp_Up);
fprintf('Maximum Ramp-Down Rate  : %d MW/hour\n', Max_Ramp_Down);
fprintf('===========================================================\n');

%% ====================================================
% PSH SYSTEM CONFIGURATION
% ====================================================
fprintf('\n================ PSH SYSTEM CONFIGURATION ================\n');

PSH_Total_Capacity = 2000;    % MW
Number_of_Units    = 4;
Unit_Capacity      = PSH_Total_Capacity / Number_of_Units;

Min_Unit_Load = 0.20 * Unit_Capacity;
Max_Unit_Load = Unit_Capacity;

Max_Generation_Power = PSH_Total_Capacity;
Max_Pumping_Power    = 1800;

Generation_Efficiency = 0.90;
Pumping_Efficiency    = 0.85;

% Reservoir Parameters
Reservoir_Capacity = 40000;      % MWh
Initial_SOC = 0.50;
Min_SOC = 0.20;
Max_SOC = 0.95;

fprintf('Total Installed Capacity     : %d MW\n', PSH_Total_Capacity);
fprintf('Number of Units              : %d\n', Number_of_Units);
fprintf('Capacity per Unit            : %d MW\n', Unit_Capacity);
fprintf('Maximum Generation Power     : %d MW\n', Max_Generation_Power);
fprintf('Maximum Pumping Power        : %d MW\n', Max_Pumping_Power);
fprintf('Generation Efficiency        : %.0f %%\n', Generation_Efficiency*100);
fprintf('Pumping Efficiency           : %.0f %%\n', Pumping_Efficiency*100);
fprintf('Reservoir Capacity           : %d MWh\n', Reservoir_Capacity);
fprintf('Initial SOC                  : %.0f %%\n', Initial_SOC*100);
fprintf('SOC Operating Range          : %.0f%% - %.0f%%\n', Min_SOC*100, Max_SOC*100);
fprintf('===========================================================\n');

%% ====================================================
% ECONOMIC PARAMETERS
% ====================================================
fprintf('\n================ ECONOMIC PARAMETERS ================\n');

% PSH Economic Parameters
PSH_Capital_Cost = 1500;              % $/kW
PSH_OM_Cost = 15;                     % $/kW/year
PSH_Lifetime = 50;                    % years
Discount_Rate = 0.08;                 % 8%

% Electricity Prices
Off_Peak_Price = 30;                  % $/MWh
Peak_Price = 120;                     % $/MWh

% SCGT Economic Parameters
SCGT_Capital_Cost = 700;              % $/kW
SCGT_OM_Cost = 10;                    % $/kW/year
SCGT_Efficiency = 0.35;               % 35%
Natural_Gas_Price = 6;                % $/MMBtu
SCGT_Heat_Rate = 10.5;                % MMBtu/MWh
SCGT_Fuel_Cost = Natural_Gas_Price * SCGT_Heat_Rate;  % $/MWh

fprintf('PSH Capital Cost            : $%.0f/kW\n', PSH_Capital_Cost);
fprintf('PSH O&M Cost                : $%.0f/kW/year\n', PSH_OM_Cost);
fprintf('PSH Project Lifetime        : %d years\n', PSH_Lifetime);
fprintf('Off-Peak Electricity Price  : $%.0f/MWh\n', Off_Peak_Price);
fprintf('Peak Electricity Price      : $%.0f/MWh\n', Peak_Price);
fprintf('SCGT Capital Cost           : $%.0f/kW\n', SCGT_Capital_Cost);
fprintf('SCGT Fuel Cost              : $%.2f/MWh\n', SCGT_Fuel_Cost);
fprintf('Discount Rate               : %.1f%%\n', Discount_Rate*100);
fprintf('===========================================================\n');

%% ====================================================
% STEP 1: PSO-BASED OPERATIONAL OPTIMIZATION
% ====================================================
fprintf('\n================ PSO OPTIMIZATION STARTED ================\n');
fprintf('Optimizing pumping/generation schedule...\n');

% PSO Parameters
n_particles = 40;
n_iterations = 150;
w = 0.7;           % Inertia weight
c1 = 1.5;          % Cognitive parameter
c2 = 1.5;          % Social parameter

% Decision variables: [Pumping_Power(1:24), Generation_Power(1:24)]
n_vars = 48;

% Initialize particles
lb = zeros(1, n_vars);
ub = [Max_Pumping_Power * ones(1,24), Max_Generation_Power * ones(1,24)];

particles = lb + (ub - lb) .* rand(n_particles, n_vars);
velocities = zeros(n_particles, n_vars);
pbest = particles;
pbest_cost = inf(n_particles, 1);
gbest = particles(1,:);
gbest_cost = inf;

% PSO Optimization Loop
pso_history = zeros(n_iterations, 1);
pso_valid_count = zeros(n_iterations, 1);

for iter = 1:n_iterations
    valid_solutions = 0;
    
    for p = 1:n_particles
        % Extract pumping and generation schedules
        pump_sched = particles(p, 1:24);
        gen_sched = particles(p, 25:48);
        
        % Evaluate fitness (objective function)
        [cost, valid, metrics] = evaluate_psh_schedule_corrected(pump_sched, gen_sched, Load, Period, ...
            Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
            Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);
        
        if valid
            valid_solutions = valid_solutions + 1;
            
            % Update personal best
            if cost < pbest_cost(p)
                pbest_cost(p) = cost;
                pbest(p,:) = particles(p,:);
            end
            
            % Update global best
            if cost < gbest_cost
                gbest_cost = cost;
                gbest = particles(p,:);
            end
        end
    end
    
    % Update velocities and positions
    for p = 1:n_particles
        r1 = rand(1, n_vars);
        r2 = rand(1, n_vars);
        
        velocities(p,:) = w * velocities(p,:) + ...
                         c1 * r1 .* (pbest(p,:) - particles(p,:)) + ...
                         c2 * r2 .* (gbest - particles(p,:));
        
        particles(p,:) = particles(p,:) + velocities(p,:);
        
        % Enforce bounds
        particles(p,:) = max(lb, min(ub, particles(p,:)));
    end
    
    pso_history(iter) = gbest_cost;
    pso_valid_count(iter) = valid_solutions;
    
    if mod(iter, 30) == 0
        fprintf('Iteration %d/%d - Best Cost: $%.2f - Valid Solutions: %d/%d\n', ...
            iter, n_iterations, gbest_cost, valid_solutions, n_particles);
    end
end

% Extract optimal schedule
Optimal_Pumping = gbest(1:24);
Optimal_Generation = gbest(25:48);

% Enforce period constraints on final solution
for h = 1:24
    if Period(h) == "OFF-PEAK"
        Optimal_Generation(h) = 0;
    else
        Optimal_Pumping(h) = 0;
    end
end

fprintf('\n✅ PSO OPTIMIZATION COMPLETED\n');
fprintf('Final Best Cost: $%.2f/day\n', gbest_cost);
fprintf('===========================================================\n');

%% ====================================================
% STEP 2: OPTIMIZED PEAK LOAD MANAGEMENT - DETAILED SIMULATION
% ====================================================
fprintf('\n================ OPTIMIZED OPERATION ANALYSIS ================\n');

% Detailed simulation with energy tracking
Reservoir_Energy = zeros(1, 25);
Reservoir_Energy(1) = Reservoir_Capacity * Initial_SOC;

Pumping_Electrical = zeros(1, 24);
Pumping_Hydraulic = zeros(1, 24);
Generation_Hydraulic = zeros(1, 24);
Generation_Electrical = zeros(1, 24);

% Simulate hour by hour
for h = 1:24
    if Period(h) == "OFF-PEAK"
        % Pumping phase
        available_space = (Reservoir_Capacity * Max_SOC) - Reservoir_Energy(h);
        max_pump_this_hour = min(Optimal_Pumping(h), available_space / Pumping_Efficiency);
        
        Pumping_Electrical(h) = max_pump_this_hour;
        Pumping_Hydraulic(h) = max_pump_this_hour * Pumping_Efficiency;
        
        Reservoir_Energy(h+1) = Reservoir_Energy(h) + Pumping_Hydraulic(h);
        
    else
        % Generation phase
        available_energy = Reservoir_Energy(h) - (Reservoir_Capacity * Min_SOC);
        max_gen_this_hour = min(Optimal_Generation(h), available_energy * Generation_Efficiency);
        
        Generation_Electrical(h) = max_gen_this_hour;
        Generation_Hydraulic(h) = max_gen_this_hour / Generation_Efficiency;
        
        Reservoir_Energy(h+1) = Reservoir_Energy(h) - Generation_Hydraulic(h);
    end
    
    % Enforce limits
    Reservoir_Energy(h+1) = max(Reservoir_Capacity * Min_SOC, ...
                               min(Reservoir_Capacity * Max_SOC, Reservoir_Energy(h+1)));
end

% Calculate totals
Total_Pumping_Electrical = sum(Pumping_Electrical);
Total_Pumping_Hydraulic = sum(Pumping_Hydraulic);
Total_Generation_Hydraulic = sum(Generation_Hydraulic);
Total_Generation_Electrical = sum(Generation_Electrical);

% Energy balance verification
Pumping_Losses = Total_Pumping_Electrical - Total_Pumping_Hydraulic;
Generation_Losses = Total_Generation_Hydraulic - Total_Generation_Electrical;
Total_Losses = Pumping_Losses + Generation_Losses;

Initial_Reservoir = Reservoir_Capacity * Initial_SOC;
Final_Reservoir = Reservoir_Energy(end);
Net_Reservoir_Change = Final_Reservoir - Initial_Reservoir;

% Round-trip efficiency
Round_Trip_Efficiency = (Total_Generation_Electrical / Total_Pumping_Electrical) * 100;
Theoretical_Efficiency = Pumping_Efficiency * Generation_Efficiency * 100;

% Calculate net load with PSH
Net_Load = Load - Generation_Electrical;

% Peak shaving metrics
Original_Peak = max(Load);
Reduced_Peak = max(Net_Load);
Peak_Reduction = Original_Peak - Reduced_Peak;
Peak_Reduction_Percent = (Peak_Reduction / Original_Peak) * 100;

% Load leveling metrics
Original_Load_Variance = var(Load);
Net_Load_Variance = var(Net_Load);
Load_Leveling_Improvement = ((Original_Load_Variance - Net_Load_Variance) / Original_Load_Variance) * 100;

% Load factor improvement
Original_Load_Factor = mean(Load) / max(Load) * 100;
Net_Load_Factor = mean(Net_Load) / max(Net_Load) * 100;
Load_Factor_Improvement = Net_Load_Factor - Original_Load_Factor;

fprintf('--- Energy Flow Analysis ---\n');
fprintf('Total Electrical Input (Pumping) : %.2f MWh\n', Total_Pumping_Electrical);
fprintf('Total Hydraulic Stored           : %.2f MWh\n', Total_Pumping_Hydraulic);
fprintf('Total Hydraulic Released         : %.2f MWh\n', Total_Generation_Hydraulic);
fprintf('Total Electrical Output (Gen)    : %.2f MWh\n', Total_Generation_Electrical);
fprintf('\n--- Efficiency Analysis ---\n');
fprintf('Pumping Efficiency (Actual)      : %.2f%% (%.2f MWh lost)\n', ...
    (Total_Pumping_Hydraulic/Total_Pumping_Electrical)*100, Pumping_Losses);
fprintf('Generation Efficiency (Actual)   : %.2f%% (%.2f MWh lost)\n', ...
    (Total_Generation_Electrical/Total_Generation_Hydraulic)*100, Generation_Losses);
fprintf('Round-Trip Efficiency            : %.2f%%\n', Round_Trip_Efficiency);
fprintf('Theoretical Maximum              : %.2f%%\n', Theoretical_Efficiency);
fprintf('Total System Losses              : %.2f MWh\n', Total_Losses);
fprintf('\n--- Reservoir Status ---\n');
fprintf('Initial Reservoir Energy         : %.2f MWh (%.1f%% SOC)\n', ...
    Initial_Reservoir, Initial_SOC*100);
fprintf('Final Reservoir Energy           : %.2f MWh (%.1f%% SOC)\n', ...
    Final_Reservoir, (Final_Reservoir/Reservoir_Capacity)*100);
fprintf('Net Reservoir Change             : %.2f MWh\n', Net_Reservoir_Change);
fprintf('\n--- Peak Management Performance ---\n');
fprintf('Original Peak Load               : %.0f MW\n', Original_Peak);
fprintf('Reduced Peak Load                : %.0f MW\n', Reduced_Peak);
fprintf('Peak Reduction                   : %.0f MW (%.2f%%)\n', Peak_Reduction, Peak_Reduction_Percent);
fprintf('Load Variance Reduction          : %.2f%%\n', Load_Leveling_Improvement);
fprintf('Original Load Factor             : %.2f%%\n', Original_Load_Factor);
fprintf('Improved Load Factor             : %.2f%%\n', Net_Load_Factor);
fprintf('Load Factor Improvement          : %.2f percentage points\n', Load_Factor_Improvement);

% Energy balance check
Hydraulic_Balance = Total_Pumping_Hydraulic - Total_Generation_Hydraulic - Net_Reservoir_Change;
fprintf('\n--- Energy Balance Verification ---\n');
fprintf('Hydraulic Balance Error          : %.4f MWh (should be ~0)\n', Hydraulic_Balance);

if abs(Hydraulic_Balance) < 0.1
    fprintf('✅ ENERGY BALANCE VERIFIED\n');
else
    fprintf('⚠️  Energy balance discrepancy detected\n');
end

if Round_Trip_Efficiency > Theoretical_Efficiency + 1
    fprintf('❌ ERROR: Round-trip efficiency exceeds theoretical maximum!\n');
else
    fprintf('✅ EFFICIENCY WITHIN PHYSICAL LIMITS\n');
end

fprintf('===========================================================\n');

%% ====================================================
% STEP 3: ECONOMIC PERFORMANCE EVALUATION (LCOE)
% ====================================================
fprintf('\n================ LCOE CALCULATION ================\n');

% Daily energy and costs
Daily_Energy_Generated = Total_Generation_Electrical;  % MWh/day
Daily_Pumping_Cost = Total_Pumping_Electrical * Off_Peak_Price;  % $/day

% Annual calculations
Days_Per_Year = 365;
Annual_Energy_Generated = Daily_Energy_Generated * Days_Per_Year;  % MWh/year
Annual_Pumping_Cost = Daily_Pumping_Cost * Days_Per_Year;  % $/year

% Capital Recovery Factor
CRF = (Discount_Rate * (1 + Discount_Rate)^PSH_Lifetime) / ...
      ((1 + Discount_Rate)^PSH_Lifetime - 1);

% Annualized costs
Annual_Capital_Cost = PSH_Capital_Cost * PSH_Total_Capacity * 1000 * CRF;  % $/year
Annual_OM_Cost = PSH_OM_Cost * PSH_Total_Capacity * 1000;                  % $/year
Total_Annual_Cost = Annual_Capital_Cost + Annual_OM_Cost + Annual_Pumping_Cost;

% LCOE
PSH_LCOE = Total_Annual_Cost / Annual_Energy_Generated;  % $/MWh

% Revenue from peak generation (if applicable)
Annual_Peak_Revenue = Daily_Energy_Generated * Peak_Price * Days_Per_Year;
Annual_Net_Cost = Total_Annual_Cost - Annual_Peak_Revenue;
Net_LCOE = Annual_Net_Cost / Annual_Energy_Generated;

fprintf('--- Daily Operations ---\n');
fprintf('Daily Energy Generated           : %.2f MWh/day\n', Daily_Energy_Generated);
fprintf('Daily Pumping Cost               : $%.2f/day\n', Daily_Pumping_Cost);
fprintf('Daily Generation Revenue         : $%.2f/day\n', Daily_Energy_Generated * Peak_Price);
fprintf('Daily Net Operating Profit       : $%.2f/day\n', ...
    Daily_Energy_Generated * Peak_Price - Daily_Pumping_Cost);

fprintf('\n--- Annual Economics ---\n');
fprintf('Annual Energy Generated          : %.0f MWh/year\n', Annual_Energy_Generated);
fprintf('Annual Capital Cost              : $%.2f M/year\n', Annual_Capital_Cost/1e6);
fprintf('Annual O&M Cost                  : $%.2f M/year\n', Annual_OM_Cost/1e6);
fprintf('Annual Pumping Cost              : $%.2f M/year\n', Annual_Pumping_Cost/1e6);
fprintf('Total Annual Cost                : $%.2f M/year\n', Total_Annual_Cost/1e6);
fprintf('Annual Peak Revenue              : $%.2f M/year\n', Annual_Peak_Revenue/1e6);
fprintf('Annual Net Cost                  : $%.2f M/year\n', Annual_Net_Cost/1e6);

fprintf('\n--- LCOE Results ---\n');
fprintf('PSH LCOE (without revenue)       : $%.2f/MWh\n', PSH_LCOE);
fprintf('Net LCOE (with peak revenue)     : $%.2f/MWh\n', Net_LCOE);
fprintf('===========================================================\n');

%% ====================================================
% STEP 4: COMPARISON WITH SCGT
% ====================================================
fprintf('\n================ PSH vs SCGT COMPARISON ================\n');

% SCGT annual costs for same energy output
SCGT_Annual_Capital = SCGT_Capital_Cost * PSH_Total_Capacity * 1000 * CRF;
SCGT_Annual_OM = SCGT_OM_Cost * PSH_Total_Capacity * 1000;
SCGT_Annual_Fuel = SCGT_Fuel_Cost * Annual_Energy_Generated;
SCGT_Total_Annual = SCGT_Annual_Capital + SCGT_Annual_OM + SCGT_Annual_Fuel;
SCGT_LCOE = SCGT_Total_Annual / Annual_Energy_Generated;

% Cost comparison
LCOE_Difference = SCGT_LCOE - PSH_LCOE;
LCOE_Savings_Percent = (LCOE_Difference / SCGT_LCOE) * 100;

% Annual savings
Annual_Cost_Savings = (SCGT_LCOE - PSH_LCOE) * Annual_Energy_Generated;

% CO2 Emissions (approximate)
SCGT_CO2_Intensity = 0.45;  % tons CO2/MWh
Annual_CO2_Avoided = SCGT_CO2_Intensity * Annual_Energy_Generated;  % tons/year
CO2_Value = 50;  % $/ton carbon price
Annual_Environmental_Benefit = Annual_CO2_Avoided * CO2_Value;

% Payback period
Initial_Investment_Difference = (PSH_Capital_Cost - SCGT_Capital_Cost) * PSH_Total_Capacity * 1000;
Simple_Payback = Initial_Investment_Difference / (Annual_Cost_Savings + Annual_Environmental_Benefit);

fprintf('--- SCGT Economics ---\n');
fprintf('SCGT Annual Capital              : $%.2f M/year\n', SCGT_Annual_Capital/1e6);
fprintf('SCGT Annual O&M                  : $%.2f M/year\n', SCGT_Annual_OM/1e6);
fprintf('SCGT Annual Fuel Cost            : $%.2f M/year\n', SCGT_Annual_Fuel/1e6);
fprintf('SCGT Total Annual Cost           : $%.2f M/year\n', SCGT_Total_Annual/1e6);
fprintf('SCGT LCOE                        : $%.2f/MWh\n', SCGT_LCOE);

fprintf('\n--- Comparative Analysis ---\n');
fprintf('PSH LCOE                         : $%.2f/MWh\n', PSH_LCOE);
fprintf('SCGT LCOE                        : $%.2f/MWh\n', SCGT_LCOE);
fprintf('Cost Difference                  : $%.2f/MWh\n', LCOE_Difference);
fprintf('Savings Percentage               : %.2f%%\n', LCOE_Savings_Percent);
fprintf('Annual Cost Savings              : $%.2f M/year\n', Annual_Cost_Savings/1e6);

fprintf('\n--- Environmental Impact ---\n');
fprintf('Annual CO2 Emissions Avoided     : %.0f tons/year\n', Annual_CO2_Avoided);
fprintf('Environmental Benefit (@$50/ton) : $%.2f M/year\n', Annual_Environmental_Benefit/1e6);

fprintf('\n--- Investment Analysis ---\n');
fprintf('Additional Capital (PSH vs SCGT) : $%.2f M\n', Initial_Investment_Difference/1e6);
fprintf('Simple Payback Period            : %.1f years\n', Simple_Payback);

if PSH_LCOE < SCGT_LCOE
    fprintf('\n✅ PSH is MORE ECONOMICAL than SCGT\n');
    fprintf('   Annual savings: $%.2f M/year\n', Annual_Cost_Savings/1e6);
else
    fprintf('\n⚠️  SCGT is more economical under current assumptions\n');
    fprintf('   PSH additional cost: $%.2f M/year\n', -Annual_Cost_Savings/1e6);
end
fprintf('===========================================================\n');

%% ====================================================
% STEP 5: SENSITIVITY ANALYSIS
% ====================================================
fprintf('\n================ SENSITIVITY ANALYSIS ================\n');

% Sensitivity parameters
Gas_Price_Range = 3:1:10;           % $/MMBtu
Pump_Cost_Range = 20:10:80;         % $/MWh
Discount_Rate_Range = 0.04:0.01:0.12;
Efficiency_Range = 0.70:0.05:0.90;  % Round-trip efficiency

% Pre-allocate results
n_gas = length(Gas_Price_Range);
n_pump = length(Pump_Cost_Range);
n_disc = length(Discount_Rate_Range);
n_eff = length(Efficiency_Range);

LCOE_vs_Gas = zeros(n_gas, 2);      % [PSH, SCGT]
LCOE_vs_Pump = zeros(n_pump, 1);
LCOE_vs_Discount = zeros(n_disc, 1);
LCOE_vs_Efficiency = zeros(n_eff, 1);
Payback_vs_Gas = zeros(n_gas, 1);

% Sensitivity to gas price
fprintf('\nAnalyzing natural gas price sensitivity...\n');
for i = 1:n_gas
    gas_price = Gas_Price_Range(i);
    scgt_fuel = gas_price * SCGT_Heat_Rate;
    scgt_annual_fuel = scgt_fuel * Annual_Energy_Generated;
    scgt_total = SCGT_Annual_Capital + SCGT_Annual_OM + scgt_annual_fuel;
    
    LCOE_vs_Gas(i,1) = PSH_LCOE;
    LCOE_vs_Gas(i,2) = scgt_total / Annual_Energy_Generated;
    
    % Payback period at this gas price
    scgt_lcoe_temp = LCOE_vs_Gas(i,2);
    savings_temp = (scgt_lcoe_temp - PSH_LCOE) * Annual_Energy_Generated;
    Payback_vs_Gas(i) = Initial_Investment_Difference / (savings_temp + Annual_Environmental_Benefit);
end

% Sensitivity to pumping cost
fprintf('Analyzing pumping cost sensitivity...\n');
for i = 1:n_pump
    pump_cost = Pump_Cost_Range(i);
    annual_pump = Total_Pumping_Electrical * pump_cost * Days_Per_Year;
    total_cost = Annual_Capital_Cost + Annual_OM_Cost + annual_pump;
    LCOE_vs_Pump(i) = total_cost / Annual_Energy_Generated;
end

% Sensitivity to discount rate
fprintf('Analyzing discount rate sensitivity...\n');
for i = 1:n_disc
    dr = Discount_Rate_Range(i);
    crf = (dr * (1 + dr)^PSH_Lifetime) / ((1 + dr)^PSH_Lifetime - 1);
    annual_cap = PSH_Capital_Cost * PSH_Total_Capacity * 1000 * crf;
    total_cost = annual_cap + Annual_OM_Cost + Annual_Pumping_Cost;
    LCOE_vs_Discount(i) = total_cost / Annual_Energy_Generated;
end

% Sensitivity to round-trip efficiency
fprintf('Analyzing efficiency sensitivity...\n');
for i = 1:n_eff
    eff = Efficiency_Range(i);
    % Adjust generation based on efficiency
    adjusted_generation = Total_Pumping_Electrical * eff;
    annual_gen_adj = adjusted_generation * Days_Per_Year;
    
    if annual_gen_adj > 0
        total_cost_adj = Annual_Capital_Cost + Annual_OM_Cost + Annual_Pumping_Cost;
        LCOE_vs_Efficiency(i) = total_cost_adj / annual_gen_adj;
    else
        LCOE_vs_Efficiency(i) = NaN;
    end
end

fprintf('✅ Sensitivity analysis completed\n');

% Find break-even gas price
breakeven_idx = find(LCOE_vs_Gas(:,2) <= PSH_LCOE, 1, 'first');
if ~isempty(breakeven_idx)
    Breakeven_Gas_Price = Gas_Price_Range(breakeven_idx);
    fprintf('\n📊 Break-even natural gas price: $%.2f/MMBtu\n', Breakeven_Gas_Price);
else
    fprintf('\n📊 PSH is economical across all gas prices analyzed\n');
end

fprintf('===========================================================\n');

%% ====================================================
% STEP 6: DECISION-MAKING FRAMEWORK
% ====================================================
fprintf('\n================ DECISION-MAKING FRAMEWORK ================\n');

% Evaluate deployment conditions
Economic_Viable = PSH_LCOE < SCGT_LCOE;
Peak_Shaving_Effective = Peak_Reduction_Percent >= 5.0;  % At least 5% reduction
Load_Leveling_Effective = Load_Leveling_Improvement >= 10.0;  % At least 10% improvement
Energy_Balance_Valid = abs(Hydraulic_Balance) < 1.0 && Round_Trip_Efficiency <= Theoretical_Efficiency + 1;
Payback_Acceptable = Simple_Payback <= 15;  % Less than 15 years
Environmental_Benefit_Significant = Annual_CO2_Avoided > 1e6;  % More than 1 million tons/year

fprintf('DEPLOYMENT CRITERIA ASSESSMENT:\n');
fprintf('--------------------------------\n');
fprintf('1. Economic Viability           : %s (PSH LCOE < SCGT LCOE)\n', ...
    iif(Economic_Viable, '✅ MET', '❌ NOT MET'));
fprintf('   - PSH LCOE: $%.2f/MWh vs SCGT: $%.2f/MWh\n', PSH_LCOE, SCGT_LCOE);

fprintf('2. Peak Shaving Effectiveness   : %s (≥5%% reduction)\n', ...
    iif(Peak_Shaving_Effective, '✅ MET', '❌ NOT MET'));
fprintf('   - Achieved: %.2f%% (%.0f MW reduction)\n', Peak_Reduction_Percent, Peak_Reduction);

fprintf('3. Load Leveling Effectiveness  : %s (≥10%% improvement)\n', ...
    iif(Load_Leveling_Effective, '✅ MET', '❌ NOT MET'));
fprintf('   - Achieved: %.2f%% variance reduction\n', Load_Leveling_Improvement);

fprintf('4. Energy Balance Integrity     : %s\n', ...
    iif(Energy_Balance_Valid, '✅ VALID', '❌ INVALID'));
fprintf('   - Hydraulic balance: %.4f MWh (error)\n', Hydraulic_Balance);
fprintf('   - Efficiency: %.2f%% (max: %.2f%%)\n', Round_Trip_Efficiency, Theoretical_Efficiency);

fprintf('5. Investment Payback           : %s (≤15 years)\n', ...
    iif(Payback_Acceptable, '✅ MET', '❌ NOT MET'));
fprintf('   - Payback period: %.1f years\n', Simple_Payback);

fprintf('6. Environmental Impact         : %s (≥1M tons CO2/year)\n', ...
    iif(Environmental_Benefit_Significant, '✅ MET', '❌ NOT MET'));
fprintf('   - CO2 avoided: %.2f M tons/year\n', Annual_CO2_Avoided/1e6);

% Overall score
criteria_met = sum([Economic_Viable, Peak_Shaving_Effective, Load_Leveling_Effective, ...
                    Energy_Balance_Valid, Payback_Acceptable, Environmental_Benefit_Significant]);
total_criteria = 6;
deployment_score = (criteria_met / total_criteria) * 100;

fprintf('\nOVERALL DEPLOYMENT SCORE: %d/%d criteria met (%.0f%%)\n', ...
    criteria_met, total_criteria, deployment_score);

fprintf('\n========== KEY FINDINGS ==========\n');
fprintf('1. Peak Load Management:\n');
fprintf('   - Original peak: %.0f MW → Reduced: %.0f MW\n', Original_Peak, Reduced_Peak);
fprintf('   - Peak reduction: %.2f%% (%.0f MW)\n', Peak_Reduction_Percent, Peak_Reduction);
fprintf('   - Load factor improvement: %.2f percentage points\n', Load_Factor_Improvement);

fprintf('\n2. Economic Performance:\n');
fprintf('   - PSH LCOE: $%.2f/MWh vs SCGT: $%.2f/MWh\n', PSH_LCOE, SCGT_LCOE);
fprintf('   - Annual cost savings: $%.2f M/year (%.2f%%)\n', ...
        Annual_Cost_Savings/1e6, LCOE_Savings_Percent);
fprintf('   - Payback period: %.1f years\n', Simple_Payback);

fprintf('\n3. Technical Performance:\n');
fprintf('   - Round-trip efficiency: %.2f%% (theoretical: %.2f%%)\n', ...
        Round_Trip_Efficiency, Theoretical_Efficiency);
fprintf('   - Daily energy throughput: %.0f MWh pumped → %.0f MWh generated\n', ...
        Total_Pumping_Electrical, Total_Generation_Electrical);
fprintf('   - Energy balance: %.4f MWh error (acceptable)\n', Hydraulic_Balance);

fprintf('\n4. Environmental Impact:\n');
fprintf('   - Annual CO2 avoided: %.2f M tons\n', Annual_CO2_Avoided/1e6);
fprintf('   - Environmental benefit: $%.2f M/year (@$50/ton)\n', ...
        Annual_Environmental_Benefit/1e6);

fprintf('\n5. Sensitivity Insights:\n');
fprintf('   - Break-even gas price: $%.2f/MMBtu\n', Breakeven_Gas_Price);
fprintf('   - LCOE range (discount 4-12%%): $%.2f - $%.2f/MWh\n', ...
        min(LCOE_vs_Discount), max(LCOE_vs_Discount));
fprintf('   - Pumping cost impact: $%.2f/MWh per $10/MWh increase\n', ...
        (LCOE_vs_Pump(end) - LCOE_vs_Pump(1)) / (Pump_Cost_Range(end) - Pump_Cost_Range(1)) * 10);

fprintf('\n========== RECOMMENDATION ==========\n');
if deployment_score >= 80
    fprintf('✅ STRONGLY RECOMMENDED for deployment\n');
    fprintf('   PSH demonstrates excellent technical and economic performance\n');
    fprintf('   with significant peak shaving and environmental benefits.\n');
    fprintf('\n   PRIORITY ACTIONS:\n');
    fprintf('   - Proceed with detailed engineering design\n');
    fprintf('   - Secure financing and regulatory approvals\n');
    fprintf('   - Develop construction timeline\n');
    
elseif deployment_score >= 60
    fprintf('⚠️  CONDITIONALLY RECOMMENDED\n');
    fprintf('   PSH shows promise but has some limitations:\n');
    if ~Economic_Viable
        fprintf('   - Economic viability needs improvement (consider subsidies)\n');
    end
    if ~Peak_Shaving_Effective
        fprintf('   - Peak shaving effectiveness below target\n');
    end
    if ~Payback_Acceptable
        fprintf('   - Payback period exceeds typical project requirements\n');
    end
    fprintf('\n   RECOMMENDED ACTIONS:\n');
    fprintf('   - Optimize operational strategy\n');
    fprintf('   - Evaluate alternative financing mechanisms\n');
    fprintf('   - Consider phased deployment\n');
    
else
    fprintf('❌ NOT RECOMMENDED under current conditions\n');
    fprintf('   Multiple criteria not met. Major issues:\n');
    if ~Economic_Viable
        fprintf('   - PSH is not cost-competitive with SCGT\n');
    end
    if ~Energy_Balance_Valid
        fprintf('   - Energy balance errors indicate model issues\n');
    end
    if ~Environmental_Benefit_Significant
        fprintf('   - Environmental benefits insufficient to justify premium\n');
    end
    fprintf('\n   ALTERNATIVE STRATEGIES:\n');
    fprintf('   - Consider battery energy storage systems\n');
    fprintf('   - Evaluate demand response programs\n');
    fprintf('   - Investigate grid-scale solar + storage\n');
end

fprintf('\n========== OPTIMAL DEPLOYMENT CONDITIONS ==========\n');
fprintf('PSH is most viable when:\n');
fprintf('1. Natural gas prices > $%.2f/MMBtu (current: $%.2f)\n', ...
    Breakeven_Gas_Price, Natural_Gas_Price);
fprintf('2. Peak/off-peak price differential > $%.0f/MWh (current: $%.0f)\n', ...
    50, Peak_Price - Off_Peak_Price);
fprintf('3. High CO2 emissions pricing (carbon tax/credits)\n');
fprintf('4. Large daily load variations (high peak-to-valley ratio)\n');
fprintf('5. Long project lifetime (50+ years) to amortize capital\n');
fprintf('6. Low discount rates (≤8%%) for infrastructure financing\n');

fprintf('===========================================================\n');

%% ====================================================
% VISUALIZATION - ALL PLOTS
% ====================================================

%% PLOT 1: PSO Convergence
figure('Color','w','Position',[50 50 1400 500]);

subplot(1,2,1);
plot(1:n_iterations, pso_history, 'LineWidth', 2.5, 'Color', [0.2 0.4 0.8]);
grid on;
xlabel('Iteration','FontSize',12,'FontWeight','bold');
ylabel('Best Cost ($)','FontSize',12,'FontWeight','bold');
title('PSO Optimization Convergence','FontSize',14,'FontWeight','bold');
xlim([1 n_iterations]);

subplot(1,2,2);
plot(1:n_iterations, pso_valid_count, 'LineWidth', 2.5, 'Color', [0.8 0.4 0.2]);
hold on;
yline(n_particles, '--k', sprintf('Total Particles (%d)', n_particles), 'LineWidth', 1.5);
grid on;
xlabel('Iteration','FontSize',12,'FontWeight','bold');
ylabel('Valid Solutions','FontSize',12,'FontWeight','bold');
title('Solution Feasibility Over Iterations','FontSize',14,'FontWeight','bold');
xlim([1 n_iterations]);
ylim([0 n_particles*1.1]);

%% PLOT 2: Optimal Operation Schedule
figure('Color','w','Position',[70 70 1400 800]);

subplot(4,1,1);
yyaxis left
bar(hours, Pumping_Electrical, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k', 'LineWidth', 1);
ylabel('Pumping Power (MW)','FontSize',11,'FontWeight','bold');
ylim([0 Max_Pumping_Power*1.2]);

yyaxis right
bar(hours, -Generation_Electrical, 'FaceColor', [0.9 0.4 0.2], 'EdgeColor', 'k', 'LineWidth', 1);
ylabel('Generation Power (MW)','FontSize',11,'FontWeight','bold');
ylim([-Max_Generation_Power*1.2 0]);

xlabel('Hour of the Day','FontSize',11,'FontWeight','bold');
title('Optimal PSH Operation Schedule (PSO-Optimized)','FontSize',13,'FontWeight','bold');
legend('Pumping', 'Generation', 'Location', 'northwest');
grid on;
xticks(1:24);
xlim([0.5 24.5]);

subplot(4,1,2);
plot(hours, Load, '-o', 'LineWidth', 2.5, 'Color', [0.8 0.2 0.2], 'MarkerSize', 7);
hold on;
plot(hours, Net_Load, '-s', 'LineWidth', 2.5, 'Color', [0.2 0.7 0.3], 'MarkerSize', 7);
yline(Original_Peak, '--r', sprintf('Original Peak: %.0f MW', Original_Peak), 'LineWidth', 1.5);
yline(Reduced_Peak, '--g', sprintf('Reduced Peak: %.0f MW (%.1f%% reduction)', ...
    Reduced_Peak, Peak_Reduction_Percent), 'LineWidth', 1.5);
grid on;
xlabel('Hour of the Day','FontSize',11,'FontWeight','bold');
ylabel('Load Demand (MW)','FontSize',11,'FontWeight','bold');
title(sprintf('Peak Shaving Performance: %.0f MW reduction (%.2f%%)', ...
      Peak_Reduction, Peak_Reduction_Percent),'FontSize',13,'FontWeight','bold');
legend('Original Load', 'Net Load (with PSH)', 'Location', 'northwest');
xticks(1:24);
xlim([0.5 24.5]);

subplot(4,1,3);
SOC_values = Reservoir_Energy / Reservoir_Capacity * 100;
plot(0:24, SOC_values, '-o', 'LineWidth', 2.5, 'Color', [0.4 0.2 0.8], 'MarkerSize', 7);
hold on;
yline(Max_SOC*100, '--r', 'Max SOC (95%)', 'LineWidth', 1.5);
yline(Min_SOC*100, '--r', 'Min SOC (20%)', 'LineWidth', 1.5);
yline(Initial_SOC*100, '--k', sprintf('Initial (%.0f%%)', Initial_SOC*100), 'LineWidth', 1.5);
fill([0 24 24 0], [Min_SOC*100 Min_SOC*100 Max_SOC*100 Max_SOC*100], ...
     [0.9 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
grid on;
xlabel('Hour of the Day','FontSize',11,'FontWeight','bold');
ylabel('State of Charge (%)','FontSize',11,'FontWeight','bold');
title(sprintf('Reservoir SOC Evolution (Final: %.1f%%)', SOC_values(end)),...
      'FontSize',13,'FontWeight','bold');
xticks(0:24);
xlim([0 24]);
ylim([0 100]);

subplot(4,1,4);
cumulative_pump = cumsum(Pumping_Electrical);
cumulative_gen = cumsum(Generation_Electrical);
plot(hours, cumulative_pump, '-o', 'LineWidth', 2.5, 'Color', [0.2 0.6 0.8], 'MarkerSize', 6);
hold on;
plot(hours, cumulative_gen, '-s', 'LineWidth', 2.5, 'Color', [0.9 0.4 0.2], 'MarkerSize', 6);
grid on;
xlabel('Hour of the Day','FontSize',11,'FontWeight','bold');
ylabel('Cumulative Energy (MWh)','FontSize',11,'FontWeight','bold');
title(sprintf('Energy Throughput (Efficiency: %.2f%%)', Round_Trip_Efficiency),...
      'FontSize',13,'FontWeight','bold');
legend(sprintf('Pumped (%.0f MWh)', Total_Pumping_Electrical), ...
       sprintf('Generated (%.0f MWh)', Total_Generation_Electrical), 'Location', 'northwest');
xticks(1:24);
xlim([0.5 24.5]);

%% PLOT 3: Economic Comparison
figure('Color','w','Position',[90 90 1400 700]);

subplot(2,3,1);
costs_psh = [Annual_Capital_Cost/1e6, Annual_OM_Cost/1e6, Annual_Pumping_Cost/1e6];
costs_scgt = [SCGT_Annual_Capital/1e6, SCGT_Annual_OM/1e6, SCGT_Annual_Fuel/1e6];
X = categorical({'Capital', 'O&M', 'Fuel/Pumping'});
X = reordercats(X, {'Capital', 'O&M', 'Fuel/Pumping'});
b = bar(X, [costs_psh; costs_scgt]', 'grouped');
b(1).FaceColor = [0.2 0.6 0.8];
b(2).FaceColor = [0.9 0.5 0.2];
ylabel('Annual Cost (M$/year)','FontSize',11,'FontWeight','bold');
title('Annual Cost Breakdown','FontSize',12,'FontWeight','bold');
legend('PSH', 'SCGT', 'Location', 'northwest');
grid on;

subplot(2,3,2);
lcoe_data = [PSH_LCOE, SCGT_LCOE];
b = bar(categorical({'PSH', 'SCGT'}), lcoe_data);
b.FaceColor = 'flat';
b.CData = [0.2 0.6 0.8; 0.9 0.5 0.2];
ylabel('LCOE ($/MWh)','FontSize',11,'FontWeight','bold');
title('Levelized Cost of Electricity','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:2
    text(i, lcoe_data(i)+3, sprintf('$%.2f', lcoe_data(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end
if PSH_LCOE < SCGT_LCOE
    text(1.5, max(lcoe_data)*0.5, sprintf('PSH saves\n$%.2f/MWh', LCOE_Difference), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', [0.8 1 0.8]);
end

subplot(2,3,3);
savings_data = [Annual_Cost_Savings/1e6, Annual_Environmental_Benefit/1e6];
b = bar(categorical({'Cost Savings', 'Environmental'}), savings_data);
b.FaceColor = 'flat';
b.CData = [0.2 0.8 0.3; 0.3 0.7 0.9];
ylabel('Annual Benefit (M$/year)','FontSize',11,'FontWeight','bold');
title('Annual Benefits vs SCGT','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:2
    text(i, savings_data(i)+0.5, sprintf('$%.1fM', savings_data(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

subplot(2,3,4);
env_data = [0, Annual_CO2_Avoided/1000];
b = bar(categorical({'PSH', 'SCGT'}), env_data);
b.FaceColor = 'flat';
b.CData = [0.2 0.8 0.3; 0.8 0.2 0.2];
ylabel('Annual CO2 Emissions (ktons)','FontSize',11,'FontWeight','bold');
title('Environmental Impact Comparison','FontSize',12,'FontWeight','bold');
grid on;
text(2, env_data(2)/2, sprintf('%.0f ktons\navoided', env_data(2)), ...
     'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'w');

subplot(2,3,5);
energy_flow = [Total_Pumping_Electrical, Pumping_Losses, Total_Pumping_Hydraulic, ...
               Generation_Losses, Total_Generation_Electrical];
flow_labels = {'Elec In', 'Pump Loss', 'Stored', 'Gen Loss', 'Elec Out'};
colors_flow = [0.2 0.6 0.8; 0.8 0.2 0.2; 0.3 0.8 0.5; 0.8 0.3 0.2; 0.9 0.5 0.2];
b = bar(energy_flow, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1);
b.CData = colors_flow;
set(gca, 'XTickLabel', flow_labels, 'FontSize', 9);
ylabel('Energy (MWh)','FontSize',11,'FontWeight','bold');
title('Daily Energy Flow','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:length(energy_flow)
    text(i, energy_flow(i)+500, sprintf('%.0f', energy_flow(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

subplot(2,3,6);
efficiency_data = [Pumping_Efficiency*100, Generation_Efficiency*100, ...
                   Round_Trip_Efficiency, Theoretical_Efficiency];
eff_labels = {'Pump η', 'Gen η', 'R-T (Actual)', 'R-T (Theory)'};
b = bar(efficiency_data, 'FaceColor', [0.6 0.4 0.8], 'EdgeColor', 'k', 'LineWidth', 1);
set(gca, 'XTickLabel', eff_labels, 'FontSize', 9);
ylabel('Efficiency (%)','FontSize',11,'FontWeight','bold');
title('System Efficiency Analysis','FontSize',12,'FontWeight','bold');
ylim([0 100]);
grid on;
for i = 1:length(efficiency_data)
    text(i, efficiency_data(i)+3, sprintf('%.1f%%', efficiency_data(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

%% PLOT 4: Sensitivity Analysis
figure('Color','w','Position',[110 110 1400 700]);

subplot(2,3,1);
plot(Gas_Price_Range, LCOE_vs_Gas(:,1), '-o', 'LineWidth', 2.5, 'Color', [0.2 0.6 0.8], 'MarkerSize', 8);
hold on;
plot(Gas_Price_Range, LCOE_vs_Gas(:,2), '-s', 'LineWidth', 2.5, 'Color', [0.9 0.5 0.2], 'MarkerSize', 8);
% Mark current gas price
xline(Natural_Gas_Price, '--k', sprintf('Current: $%.0f', Natural_Gas_Price), 'LineWidth', 1.5);
% Mark break-even
if exist('Breakeven_Gas_Price', 'var')
    xline(Breakeven_Gas_Price, '--g', sprintf('Break-even: $%.1f', Breakeven_Gas_Price), 'LineWidth', 1.5);
end
grid on;
xlabel('Natural Gas Price ($/MMBtu)','FontSize',11,'FontWeight','bold');
ylabel('LCOE ($/MWh)','FontSize',11,'FontWeight','bold');
title('Sensitivity to Gas Price','FontSize',12,'FontWeight','bold');
legend('PSH', 'SCGT', 'Location', 'northwest');

subplot(2,3,2);
plot(Pump_Cost_Range, LCOE_vs_Pump, '-o', 'LineWidth', 2.5, 'Color', [0.6 0.3 0.8], 'MarkerSize', 8);
hold on;
xline(Off_Peak_Price, '--k', sprintf('Current: $%.0f', Off_Peak_Price), 'LineWidth', 1.5);
grid on;
xlabel('Pumping Cost ($/MWh)','FontSize',11,'FontWeight','bold');
ylabel('PSH LCOE ($/MWh)','FontSize',11,'FontWeight','bold');
title('Sensitivity to Pumping Cost','FontSize',12,'FontWeight','bold');

subplot(2,3,3);
plot(Discount_Rate_Range*100, LCOE_vs_Discount, '-o', 'LineWidth', 2.5, 'Color', [0.8 0.4 0.3], 'MarkerSize', 8);
hold on;
xline(Discount_Rate*100, '--k', sprintf('Current: %.0f%%', Discount_Rate*100), 'LineWidth', 1.5);
grid on;
xlabel('Discount Rate (%)','FontSize',11,'FontWeight','bold');
ylabel('PSH LCOE ($/MWh)','FontSize',11,'FontWeight','bold');
title('Sensitivity to Discount Rate','FontSize',12,'FontWeight','bold');

subplot(2,3,4);
plot(Efficiency_Range*100, LCOE_vs_Efficiency, '-o', 'LineWidth', 2.5, 'Color', [0.3 0.7 0.5], 'MarkerSize', 8);
hold on;
xline(Round_Trip_Efficiency, '--k', sprintf('Current: %.1f%%', Round_Trip_Efficiency), 'LineWidth', 1.5);
grid on;
xlabel('Round-Trip Efficiency (%)','FontSize',11,'FontWeight','bold');
ylabel('PSH LCOE ($/MWh)','FontSize',11,'FontWeight','bold');
title('Sensitivity to Efficiency','FontSize',12,'FontWeight','bold');

subplot(2,3,5);
plot(Gas_Price_Range, Payback_vs_Gas, '-o', 'LineWidth', 2.5, 'Color', [0.9 0.4 0.5], 'MarkerSize', 8);
hold on;
xline(Natural_Gas_Price, '--k', sprintf('Current: $%.0f', Natural_Gas_Price), 'LineWidth', 1.5);
yline(15, '--r', 'Max Acceptable (15y)', 'LineWidth', 1.5);
grid on;
xlabel('Natural Gas Price ($/MMBtu)','FontSize',11,'FontWeight','bold');
ylabel('Payback Period (years)','FontSize',11,'FontWeight','bold');
title('Payback vs Gas Price','FontSize',12,'FontWeight','bold');

subplot(2,3,6);
% Tornado diagram - show impact range
param_names = {'Gas Price', 'Pump Cost', 'Discount Rate', 'Efficiency'};
base_lcoe = PSH_LCOE;
lcoe_ranges = [
    max(LCOE_vs_Gas(:,1)) - min(LCOE_vs_Gas(:,1));
    max(LCOE_vs_Pump) - min(LCOE_vs_Pump);
    max(LCOE_vs_Discount) - min(LCOE_vs_Discount);
    max(LCOE_vs_Efficiency) - min(LCOE_vs_Efficiency)
];
[sorted_ranges, sort_idx] = sort(lcoe_ranges, 'descend');
sorted_names = param_names(sort_idx);

barh(categorical(sorted_names), sorted_ranges, 'FaceColor', [0.7 0.5 0.9], 'EdgeColor', 'k');
xlabel('LCOE Variation Range ($/MWh)','FontSize',11,'FontWeight','bold');
title('Sensitivity Tornado Diagram','FontSize',12,'FontWeight','bold');
grid on;

%% PLOT 5: Decision Framework Summary
figure('Color','w','Position',[130 130 1400 800]);

subplot(2,3,1);
metrics = [Peak_Reduction_Percent, Load_Leveling_Improvement, Load_Factor_Improvement, ...
           Round_Trip_Efficiency];
metric_labels = {'Peak Reduction (%)', 'Variance Reduction (%)', ...
                 'Load Factor Δ (pp)', 'Efficiency (%)'};
b = barh(categorical(metric_labels), metrics);
b.FaceColor = [0.3 0.7 0.5];
b.EdgeColor = 'k';
xlabel('Value','FontSize',11,'FontWeight','bold');
title('Performance Metrics','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:length(metrics)
    text(metrics(i)+1, i, sprintf('%.2f', metrics(i)), 'FontSize', 9, 'FontWeight', 'bold');
end

subplot(2,3,2);
savings_comparison = [LCOE_Savings_Percent, (Annual_Environmental_Benefit/(Annual_Cost_Savings+Annual_Environmental_Benefit))*100];
b = bar(categorical({'Cost Savings', 'Enviro. Benefit'}), savings_comparison);
b.FaceColor = 'flat';
b.CData = [0.2 0.6 0.8; 0.3 0.8 0.3];
b.EdgeColor = 'k';
ylabel('Contribution (%)','FontSize',11,'FontWeight','bold');
title('Benefit Breakdown vs SCGT','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:2
    text(i, savings_comparison(i)+2, sprintf('%.1f%%', savings_comparison(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

subplot(2,3,3);
financial_metrics = [Simple_Payback, PSH_Lifetime];
b = bar(categorical({'Payback (years)', 'Lifetime (years)'}), financial_metrics);
b.FaceColor = 'flat';
b.CData = [0.9 0.5 0.2; 0.5 0.5 0.9];
b.EdgeColor = 'k';
ylabel('Years','FontSize',11,'FontWeight','bold');
title('Investment Timeline','FontSize',12,'FontWeight','bold');
grid on;
for i = 1:2
    text(i, financial_metrics(i)+2, sprintf('%.1f', financial_metrics(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

subplot(2,3,[4 5]);
criteria_names = {'Economic', 'Peak Shaving', 'Load Leveling', 'Energy Balance', ...
                  'Payback', 'Environment'};
criteria_values = [Economic_Viable, Peak_Shaving_Effective, Load_Leveling_Effective, ...
                   Energy_Balance_Valid, Payback_Acceptable, Environmental_Benefit_Significant];
colors_criteria = repmat([0.8 0.2 0.2], 6, 1);
colors_criteria(criteria_values == 1, :) = repmat([0.2 0.8 0.3], sum(criteria_values), 1);

b = bar(categorical(criteria_names), criteria_values);
b.FaceColor = 'flat';
b.CData = colors_criteria;
b.EdgeColor = 'k';
ylim([0 1.3]);
ylabel('Status','FontSize',11,'FontWeight','bold');
title(sprintf('Deployment Criteria Assessment (%d/%d met = %.0f%%)', ...
      criteria_met, total_criteria, deployment_score), 'FontSize',12,'FontWeight','bold');
set(gca, 'YTick', [0 1], 'YTickLabel', {'Not Met', 'Met'});
grid on;

for i = 1:6
    if criteria_values(i)
        text(i, 1.1, '✓', 'FontSize', 24, 'HorizontalAlignment', 'center', 'Color', [0 0.6 0]);
    else
        text(i, 0.5, '✗', 'FontSize', 24, 'HorizontalAlignment', 'center', 'Color', [0.8 0 0]);
    end
end

subplot(2,3,6);
% Overall recommendation gauge
theta = linspace(0, pi, 100);
r_outer = 1;
r_inner = 0.6;

% Background segments
hold on;
fill([0 r_outer*cos(theta(1:33)) 0], [0 r_outer*sin(theta(1:33)) 0], ...
     [0.8 0.2 0.2], 'EdgeColor', 'k', 'FaceAlpha', 0.7);
fill([0 r_outer*cos(theta(34:66)) 0], [0 r_outer*sin(theta(34:66)) 0], ...
     [0.9 0.7 0.2], 'EdgeColor', 'k', 'FaceAlpha', 0.7);
fill([0 r_outer*cos(theta(67:100)) 0], [0 r_outer*sin(theta(67:100)) 0], ...
     [0.2 0.8 0.3], 'EdgeColor', 'k', 'FaceAlpha', 0.7);

% White center
fill(r_inner*cos(theta), r_inner*sin(theta), 'w', 'EdgeColor', 'k');

% Needle based on score
needle_angle = (deployment_score/100) * pi;
plot([0 r_outer*0.9*cos(needle_angle)], [0 r_outer*0.9*sin(needle_angle)], ...
     'k-', 'LineWidth', 4);
plot(0, 0, 'ko', 'MarkerSize', 12, 'MarkerFaceColor', 'k');

axis equal;
axis off;
xlim([-1.2 1.2]);
ylim([-0.3 1.2]);

text(0, -0.15, sprintf('%.0f%%', deployment_score), 'FontSize', 16, ...
     'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(0, 1.35, 'DEPLOYMENT READINESS', 'FontSize', 11, ...
     'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(-r_outer*0.9, -0.05, 'Not Ready', 'FontSize', 8, 'Color', [0.6 0 0]);
text(0, r_outer*1.1, 'Conditional', 'FontSize', 8, 'Color', [0.7 0.5 0]);
text(r_outer*0.9, -0.05, 'Ready', 'FontSize', 8, 'Color', [0 0.5 0]);

%% Save Results to Excel
fprintf('\n================ SAVING RESULTS ================\n');

% Main results table
T_Results = table(hours', Load', Pumping_Electrical', Generation_Electrical', Net_Load', ...
    SOC_values(1:24)', Pumping_Hydraulic', Generation_Hydraulic', ...
    'VariableNames', {'Hour','Original_Load_MW','Pumping_MW','Generation_MW','Net_Load_MW', ...
                      'SOC_Percent','Hydraulic_Stored_MWh','Hydraulic_Released_MWh'});

% Summary table
Summary = table(...
    {'Total Electrical Input (MWh)'; 'Total Hydraulic Stored (MWh)'; ...
     'Total Hydraulic Released (MWh)'; 'Total Electrical Output (MWh)'; ...
     'Pumping Efficiency (%)'; 'Generation Efficiency (%)'; 'Round-Trip Efficiency (%)'; ...
     'Peak Reduction (MW)'; 'Peak Reduction (%)'; 'Load Variance Reduction (%)'; ...
     'PSH LCOE ($/MWh)'; 'SCGT LCOE ($/MWh)'; 'Cost Savings ($/MWh)'; ...
     'Annual Cost Savings ($M/year)'; 'Payback Period (years)'; ...
     'Annual CO2 Avoided (tons)'; 'Deployment Score (%)'}, ...
    [Total_Pumping_Electrical; Total_Pumping_Hydraulic; Total_Generation_Hydraulic; ...
     Total_Generation_Electrical; (Total_Pumping_Hydraulic/Total_Pumping_Electrical)*100; ...
     (Total_Generation_Electrical/Total_Generation_Hydraulic)*100; Round_Trip_Efficiency; ...
     Peak_Reduction; Peak_Reduction_Percent; Load_Leveling_Improvement; ...
     PSH_LCOE; SCGT_LCOE; LCOE_Difference; Annual_Cost_Savings/1e6; Simple_Payback; ...
     Annual_CO2_Avoided; deployment_score], ...
    'VariableNames', {'Parameter', 'Value'});

% Sensitivity tables
T_Gas = table(Gas_Price_Range', LCOE_vs_Gas(:,1), LCOE_vs_Gas(:,2), Payback_vs_Gas, ...
    'VariableNames', {'Gas_Price_$/MMBtu','PSH_LCOE_$/MWh','SCGT_LCOE_$/MWh','Payback_years'});

T_Pump = table(Pump_Cost_Range', LCOE_vs_Pump, ...
    'VariableNames', {'Pumping_Cost_$/MWh','PSH_LCOE_$/MWh'});

T_Discount = table(Discount_Rate_Range'*100, LCOE_vs_Discount, ...
    'VariableNames', {'Discount_Rate_%','PSH_LCOE_$/MWh'});

% Write to Excel
filename = 'Egypt_PSH_Complete_Analysis.xlsx';
writetable(T_Results, filename, 'Sheet', 'Hourly_Operation');
writetable(Summary, filename, 'Sheet', 'Summary');
writetable(T_Gas, filename, 'Sheet', 'Sensitivity_Gas_Price');
writetable(T_Pump, filename, 'Sheet', 'Sensitivity_Pump_Cost');
writetable(T_Discount, filename, 'Sheet', 'Sensitivity_Discount_Rate');

fprintf('✅ All results saved to: %s\n', filename);
fprintf('   - Hourly_Operation: Detailed hourly data\n');
fprintf('   - Summary: Key performance metrics\n');
fprintf('   - Sensitivity_*: Sensitivity analysis results\n');

fprintf('\n====================================================\n');
fprintf(' COMPLETE ANALYSIS FINISHED SUCCESSFULLY\n');
fprintf('====================================================\n');

%% ====================================================
% SUPPORTING FUNCTIONS
% ====================================================

function [cost, valid, metrics] = evaluate_psh_schedule_corrected(pump, gen, Load, Period, ...
    Max_Pump, Max_Gen, Pump_Eff, Gen_Eff, Res_Cap, Init_SOC, Min_SOC, Max_SOC, ...
    Off_Peak_Price, Peak_Price)
    
    % Initialize
    reservoir = Res_Cap * Init_SOC;
    valid = true;
    
    total_pump_cost = 0;
    total_gen_revenue = 0;
    peak_demand = 0;
    
    pump_energy_total = 0;
    gen_energy_total = 0;
    
    % Simulate 24-hour operation
    for h = 1:24
        % Enforce period constraints
        if Period(h) == "OFF-PEAK"
            gen(h) = 0;  % No generation during off-peak
        else
            pump(h) = 0;  % No pumping during peak
        end
        
        % Pumping phase
        if pump(h) > 0
            % Check if we can pump this much
            available_space = (Res_Cap * Max_SOC) - reservoir;
            max_pump_possible = available_space / Pump_Eff;
            
            actual_pump = min([pump(h), Max_Pump, max_pump_possible]);
            
            if actual_pump < 0
                actual_pump = 0;
            end
            
            energy_stored = actual_pump * Pump_Eff;
            reservoir = reservoir + energy_stored;
            
            total_pump_cost = total_pump_cost + actual_pump * Off_Peak_Price;
            pump_energy_total = pump_energy_total + actual_pump;
        end
        
        % Generation phase
        if gen(h) > 0
            % Check if we have enough stored energy
            available_energy = reservoir - (Res_Cap * Min_SOC);
            max_gen_possible = available_energy * Gen_Eff;
            
            actual_gen = min([gen(h), Max_Gen, max_gen_possible]);
            
            if actual_gen < 0
                actual_gen = 0;
            end
            
            energy_released = actual_gen / Gen_Eff;
            reservoir = reservoir - energy_released;
            
            total_gen_revenue = total_gen_revenue + actual_gen * Peak_Price;
            gen_energy_total = gen_energy_total + actual_gen;
        end
        
        % Check reservoir limits
        if reservoir < Res_Cap * Min_SOC - 0.1 || reservoir > Res_Cap * Max_SOC + 0.1
            valid = false;
        end
        
        % Track net peak demand
        net_load = Load(h) - (gen(h) > 0) * gen(h);
        peak_demand = max(peak_demand, net_load);
    end
    
    % Check energy balance (can't generate more than pumped)
    theoretical_max_gen = pump_energy_total * Pump_Eff * Gen_Eff;
    if gen_energy_total > theoretical_max_gen * 1.01  % Allow 1% tolerance
        valid = false;
    end
    
    % Objective function
    % Minimize: pumping cost - generation revenue + penalty for high peak
    peak_penalty = peak_demand * 5;  % Weight for peak demand
    cost = total_pump_cost - total_gen_revenue + peak_penalty;
    
    % Additional penalty for invalid solutions
    if ~valid
        cost = cost + 1e8;
    end
    
    % Return metrics
    metrics.pump_total = pump_energy_total;
    metrics.gen_total = gen_energy_total;
    metrics.peak = peak_demand;
    metrics.efficiency = gen_energy_total / max(pump_energy_total, 0.001) * 100;
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end