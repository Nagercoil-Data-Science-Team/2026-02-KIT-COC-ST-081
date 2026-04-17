clc;
clear;
close all;

fprintf('====================================================\n');
fprintf(' EGYPT PSH SYSTEM - PSO vs GA OPTIMIZATION COMPARISON\n');
fprintf(' WITH SEASONAL ANALYSIS & ENVIRONMENTAL METRICS\n');
fprintf('====================================================\n\n');

%% -----------------------------
% SEASONAL CONFIGURATION FOR EGYPT
% -----------------------------
fprintf('================ SEASONAL ANALYSIS FOR EGYPT ================\n');

Season_Names = ["Summer", "Autumn", "Winter", "Spring"];
Season_Factors = [1.35, 1.10, 0.85, 1.05];
Season_Descriptions = ["PEAK - Extreme Heat & AC", "MODERATE - Transitional", ...
                       "LOW - Mild Weather", "MODERATE - Pleasant"];

Current_Season = 1;  % Default: Summer (highest demand)

Current_Season_Name = Season_Names(Current_Season);
Current_Season_Factor = Season_Factors(Current_Season);
Current_Season_Desc = Season_Descriptions(Current_Season);

fprintf('CURRENT SEASON SELECTED: %s\n', Current_Season_Name);
fprintf('Season Type: %s\n', Current_Season_Desc);
fprintf('Load Multiplier: %.2f (%.0f%% of base load)\n', ...
    Current_Season_Factor, Current_Season_Factor*100);
fprintf('===========================================================\n\n');

%% -----------------------------
% TIME SETUP
% -----------------------------
hours    = 1:24;
time_sec = (hours - 1) * 3600;

%% -----------------------------
% BASE LOAD GENERATION (FORMULA-BASED)
% -----------------------------
Base_Load = zeros(1,24);
Base_Load(1:6)   = 18000 + 500*sin(linspace(0,pi,6));
Base_Load(7:11)  = 25500 + 7500*sin(linspace(0,pi,5));
Base_Load(12:17) = linspace(30500,18000,6);
Base_Load(18:23) = 24000 + 14000*sin(linspace(0,pi,6));
Base_Load(24)    = 24000;
Base_Load = round(Base_Load);
Load = round(Base_Load * Current_Season_Factor);

fprintf('================ LOAD PROFILE INFORMATION ================\n');
fprintf('Base Load Range       : %d - %d MW\n', min(Base_Load), max(Base_Load));
fprintf('Seasonal Load Range   : %d - %d MW\n', min(Load), max(Load));
fprintf('Seasonal Increase     : %.1f%% over base load\n', (Current_Season_Factor-1)*100);
fprintf('===========================================================\n\n');

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

%% ====================================================
% ENVIRONMENTAL PARAMETERS
% ====================================================
% Egypt grid emission factor (tCO2/MWh) - based on Egyptian electricity mix
% Egypt grid: ~65% natural gas, ~20% oil, ~15% renewables
Grid_Emission_Factor = 0.536;   % tCO2/MWh (Egyptian grid average)

% Peak thermal plant (SCGT/oil peaker) emission factor - higher than grid avg
% Peaker plants typically run on diesel/light oil -> higher emissions
Peak_Thermal_Emission_Factor = 0.750;  % tCO2/MWh (peaker plant)

% PSH operational emissions (pumping from grid - night mix is cleaner)
% Night grid in Egypt is dominated by gas baseload -> slightly lower
Night_Grid_Emission_Factor = 0.480;   % tCO2/MWh (off-peak night grid)

% SCGT Peaker assumed to be displaced during peak hours by PSH generation
% Thermal peaker capacity factor used to estimate displacement
SCGT_Efficiency = 0.35;
Natural_Gas_Price = 6;           % $/MMBtu
SCGT_Heat_Rate = 10.5;           % MMBtu/MWh

fprintf('================ ENVIRONMENTAL PARAMETERS ================\n');
fprintf('Egyptian Grid Emission Factor    : %.3f tCO2/MWh\n', Grid_Emission_Factor);
fprintf('Peak Thermal Emission Factor     : %.3f tCO2/MWh\n', Peak_Thermal_Emission_Factor);
fprintf('Off-Peak Grid Emission Factor    : %.3f tCO2/MWh\n', Night_Grid_Emission_Factor);
fprintf('(Based on Egyptian grid mix: ~65%% gas, ~20%% oil, ~15%% renewables)\n');
fprintf('===========================================================\n\n');

%% ====================================================
% PSH SYSTEM CONFIGURATION
% ====================================================
fprintf('================ PSH SYSTEM CONFIGURATION ================\n');

PSH_Total_Capacity = 2000;
Number_of_Units    = 4;
Unit_Capacity      = PSH_Total_Capacity / Number_of_Units;
Max_Generation_Power = PSH_Total_Capacity;
Max_Pumping_Power    = 1800;
Generation_Efficiency = 0.90;
Pumping_Efficiency    = 0.85;
Reservoir_Capacity = 40000;
Initial_SOC = 0.50;
Min_SOC = 0.20;
Max_SOC = 0.95;

fprintf('Total Installed Capacity     : %d MW\n', PSH_Total_Capacity);
fprintf('Number of Units              : %d\n', Number_of_Units);
fprintf('Maximum Generation Power     : %d MW\n', Max_Generation_Power);
fprintf('Maximum Pumping Power        : %d MW\n', Max_Pumping_Power);
fprintf('Generation Efficiency        : %.0f %%\n', Generation_Efficiency*100);
fprintf('Pumping Efficiency           : %.0f %%\n', Pumping_Efficiency*100);
fprintf('Reservoir Capacity           : %d MWh\n', Reservoir_Capacity);
fprintf('Initial SOC                  : %.0f %%\n', Initial_SOC*100);
fprintf('===========================================================\n');

%% ====================================================
% ECONOMIC PARAMETERS
% ====================================================
fprintf('\n================ ECONOMIC PARAMETERS ================\n');
PSH_Capital_Cost = 1500;
PSH_OM_Cost = 15;
PSH_Lifetime = 50;
Discount_Rate = 0.08;
Off_Peak_Price = 30;
Peak_Price = 120;
if Current_Season == 1
    Peak_Price = Peak_Price * 1.2;
    fprintf('Summer peak price adjustment applied (+20%%)\n');
end
SCGT_Capital_Cost = 700;
SCGT_OM_Cost = 10;
SCGT_Fuel_Cost = Natural_Gas_Price * SCGT_Heat_Rate;

fprintf('Off-Peak Price : $%.0f/MWh | Peak Price : $%.0f/MWh\n', Off_Peak_Price, Peak_Price);
fprintf('SCGT Fuel Cost : $%.2f/MWh\n', SCGT_Fuel_Cost);
fprintf('===========================================================\n');

%% ====================================================
% OPTIMIZATION SETUP
% ====================================================
n_vars = 48;
lb = zeros(1, n_vars);
ub = zeros(1, n_vars);
for h = 1:24
    if Period(h) == "OFF-PEAK"
        ub(h) = Max_Pumping_Power;
        ub(h+24) = 0;
    else
        ub(h) = 0;
        ub(h+24) = Max_Generation_Power;
    end
end

%% ====================================================
% OPTIMIZATION 1: PSO
% ====================================================
fprintf('\n================ PSO OPTIMIZATION STARTED ================\n');
pso_particles = 50; pso_iterations = 200;
w = 0.7; c1 = 1.5; c2 = 1.5;
particles = lb + (ub - lb) .* rand(pso_particles, n_vars);
velocities = zeros(pso_particles, n_vars);
pbest = particles;
pbest_cost = inf(pso_particles, 1);
gbest_pso = particles(1,:);
gbest_cost_pso = inf;
pso_history = zeros(pso_iterations, 1);
pso_valid_count = zeros(pso_iterations, 1);
pso_time_start = tic;

for iter = 1:pso_iterations
    valid_solutions = 0;
    for p = 1:pso_particles
        pump_sched = particles(p, 1:24);
        gen_sched = particles(p, 25:48);
        [cost, valid, ~] = evaluate_psh_schedule_corrected(pump_sched, gen_sched, Load, Period, ...
            Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
            Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);
        if valid
            valid_solutions = valid_solutions + 1;
            if cost < pbest_cost(p), pbest_cost(p) = cost; pbest(p,:) = particles(p,:); end
            if cost < gbest_cost_pso, gbest_cost_pso = cost; gbest_pso = particles(p,:); end
        end
    end
    for p = 1:pso_particles
        r1 = rand(1, n_vars); r2 = rand(1, n_vars);
        velocities(p,:) = w*velocities(p,:) + c1*r1.*(pbest(p,:)-particles(p,:)) + c2*r2.*(gbest_pso-particles(p,:));
        particles(p,:) = max(lb, min(ub, particles(p,:) + velocities(p,:)));
    end
    pso_history(iter) = gbest_cost_pso;
    pso_valid_count(iter) = valid_solutions;
    if mod(iter, 40) == 0
        fprintf('PSO Iter %d/%d - Best Cost: $%.2f - Valid: %d/%d\n', iter, pso_iterations, gbest_cost_pso, valid_solutions, pso_particles);
    end
end
pso_time = toc(pso_time_start);
PSO_Pumping = gbest_pso(1:24);
PSO_Generation = gbest_pso(25:48);
fprintf('\n PSO OPTIMIZATION COMPLETED - Cost: $%.2f/day | Time: %.2f sec\n', gbest_cost_pso, pso_time);
fprintf('===========================================================\n');

%% ====================================================
% OPTIMIZATION 2: GA
% ====================================================
fprintf('\n================ GA OPTIMIZATION STARTED ================\n');
ga_population = 50; ga_generations = 200;
crossover_rate = 0.8; mutation_rate = 0.1;
elite_count = 2; tournament_size = 3;
population = lb + (ub - lb) .* rand(ga_population, n_vars);
fitness = inf(ga_population, 1);
ga_history = zeros(ga_generations, 1);
ga_valid_count = zeros(ga_generations, 1);
ga_avg_fitness = zeros(ga_generations, 1);
ga_time_start = tic;

for gen = 1:ga_generations
    valid_solutions = 0;
    for i = 1:ga_population
        pump_sched = population(i, 1:24);
        gen_sched = population(i, 25:48);
        [cost, valid, ~] = evaluate_psh_schedule_corrected(pump_sched, gen_sched, Load, Period, ...
            Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
            Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);
        fitness(i) = cost;
        if valid, valid_solutions = valid_solutions + 1; end
    end
    [best_fitness, ~] = min(fitness);
    ga_history(gen) = best_fitness;
    ga_valid_count(gen) = valid_solutions;
    ga_avg_fitness(gen) = mean(fitness(fitness < 1e9));
    if mod(gen, 40) == 0
        fprintf('GA Gen %d/%d - Best Cost: $%.2f - Valid: %d/%d\n', gen, ga_generations, best_fitness, valid_solutions, ga_population);
    end
    new_population = zeros(ga_population, n_vars);
    [~, sorted_idx] = sort(fitness);
    for i = 1:elite_count, new_population(i,:) = population(sorted_idx(i),:); end
    for i = elite_count+1:ga_population
        parent1 = tournament_selection(population, fitness, tournament_size);
        parent2 = tournament_selection(population, fitness, tournament_size);
        offspring = iif(rand < crossover_rate, crossover(parent1, parent2), parent1);
        new_population(i,:) = mutate(offspring, lb, ub, mutation_rate);
    end
    population = new_population;
end
ga_time = toc(ga_time_start);
[gbest_cost_ga, best_idx] = min(fitness);
gbest_ga = population(best_idx,:);
GA_Pumping = gbest_ga(1:24);
GA_Generation = gbest_ga(25:48);
fprintf('\n GA OPTIMIZATION COMPLETED - Cost: $%.2f/day | Time: %.2f sec\n', gbest_cost_ga, ga_time);
fprintf('===========================================================\n');

%% ====================================================
% DETAILED METRICS EVALUATION
% ====================================================
[pso_metrics] = evaluate_detailed_metrics(PSO_Pumping, PSO_Generation, Load, Period, ...
    Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
    Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);

[ga_metrics] = evaluate_detailed_metrics(GA_Pumping, GA_Generation, Load, Period, ...
    Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
    Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);

%% ====================================================
% CO2 & THERMAL DISPLACEMENT CALCULATIONS (CORRECTED)
% ====================================================
% Physical sanity check on generation/pumping totals
% Max possible generation = Max_Generation_Power * Peak_Hours
% Max possible pumping    = Max_Pumping_Power    * OffPeak_Hours
Peak_Hours_Count   = sum(Period == "PEAK");        % hours
OffPeak_Hours_Count = 24 - Peak_Hours_Count;       % hours

% Theoretical max (MW * hrs = MWh), further limited by reservoir
Max_Possible_Gen_MWh  = min(Max_Generation_Power * Peak_Hours_Count, ...
                             Reservoir_Capacity * (Max_SOC - Min_SOC) * Generation_Efficiency);
Max_Possible_Pump_MWh = min(Max_Pumping_Power * OffPeak_Hours_Count, ...
                             Reservoir_Capacity * (Max_SOC - Min_SOC) / Pumping_Efficiency);

% Clamp actual values to physical limits (guard against optimizer artefacts)
PSO_gen_actual  = min(pso_metrics.gen_total,  Max_Possible_Gen_MWh);
PSO_pump_actual = min(pso_metrics.pump_total, Max_Possible_Pump_MWh);
GA_gen_actual   = min(ga_metrics.gen_total,   Max_Possible_Gen_MWh);
GA_pump_actual  = min(ga_metrics.pump_total,  Max_Possible_Pump_MWh);

% Energy conservation check: generation cannot exceed pumped * round-trip efficiency
RT_Efficiency = Pumping_Efficiency * Generation_Efficiency;   % ~0.765
PSO_gen_actual = min(PSO_gen_actual, PSO_pump_actual * RT_Efficiency);
GA_gen_actual  = min(GA_gen_actual,  GA_pump_actual  * RT_Efficiency);

% ---- CO2 Calculation (per day) ----
% Gross CO2 avoided  = PSH generation replaces equivalent thermal peaker output
% CO2 penalty        = pumping draws from grid (off-peak, lower emission factor)
PSO_CO2_Displaced = PSO_gen_actual  * Peak_Thermal_Emission_Factor;   % tCO2/day
PSO_CO2_Pumping   = PSO_pump_actual * Night_Grid_Emission_Factor;     % tCO2/day
PSO_CO2_Net_Saved = PSO_CO2_Displaced - PSO_CO2_Pumping;              % tCO2/day (net)

GA_CO2_Displaced  = GA_gen_actual   * Peak_Thermal_Emission_Factor;
GA_CO2_Pumping    = GA_pump_actual  * Night_Grid_Emission_Factor;
GA_CO2_Net_Saved  = GA_CO2_Displaced - GA_CO2_Pumping;

% ---- Annualized (operational days: exclude ~15 maintenance days/yr) ----
Operational_Days = 350;
PSO_CO2_Annual        = PSO_CO2_Net_Saved  * Operational_Days;          % tCO2/yr
GA_CO2_Annual         = GA_CO2_Net_Saved   * Operational_Days;

% ---- Peak Thermal Generation Reduction ----
% Actual MWh displaced per day (gen_actual already clamped)
PSO_Thermal_Displaced_MWh    = PSO_gen_actual;
GA_Thermal_Displaced_MWh     = GA_gen_actual;

% Average MW reduction during peak hours
PSO_Thermal_Peak_MW_Reduction = PSO_Thermal_Displaced_MWh / Peak_Hours_Count;
GA_Thermal_Peak_MW_Reduction  = GA_Thermal_Displaced_MWh  / Peak_Hours_Count;

% Peaker capacity avoided = peak load reduction (MW) from PSH
% This is the reduction in maximum instantaneous peak, NOT energy
PSO_Peaker_Capacity_Avoided = pso_metrics.peak_reduction;   % MW
GA_Peaker_Capacity_Avoided  = ga_metrics.peak_reduction;    % MW

% Annualized thermal displacement
PSO_Thermal_Annual_MWh = PSO_Thermal_Displaced_MWh * Operational_Days;
GA_Thermal_Annual_MWh  = GA_Thermal_Displaced_MWh  * Operational_Days;

fprintf('\n--- PHYSICAL VALIDATION ---\n');
fprintf('Max possible generation (MWh/day) : %.2f\n', Max_Possible_Gen_MWh);
fprintf('Max possible pumping   (MWh/day)  : %.2f\n', Max_Possible_Pump_MWh);
fprintf('PSO gen used (clamped) : %.2f MWh | pump used: %.2f MWh\n', PSO_gen_actual, PSO_pump_actual);
fprintf('GA  gen used (clamped) : %.2f MWh | pump used: %.2f MWh\n', GA_gen_actual,  GA_pump_actual);
fprintf('Round-trip efficiency  : %.1f%%\n', RT_Efficiency*100);

%% ====================================================
% COMPREHENSIVE COMMAND WINDOW RESULTS
% ====================================================
fprintf('\n\n');
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║         PSO vs GA OPTIMIZATION COMPARISON - %s SEASON         ║\n', upper(Current_Season_Name));
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('                 OPTIMIZATION PERFORMANCE SUMMARY\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Metric                              PSO              GA\n');
fprintf('────────────────────────────────────────────────────────────────────\n');
fprintf('Final Cost ($/day)              : $%-15.2f $%.2f\n', -gbest_cost_pso, -gbest_cost_ga);
fprintf('Computation Time (sec)          : %-15.2f %.2f\n', pso_time, ga_time);
fprintf('Total Pumping Energy (MWh)      : %-15.2f %.2f\n', pso_metrics.pump_total, ga_metrics.pump_total);
fprintf('Total Generation Energy (MWh)   : %-15.2f %.2f\n', pso_metrics.gen_total, ga_metrics.gen_total);
fprintf('Round-Trip Efficiency (%%)       : %-15.2f %.2f\n', pso_metrics.efficiency, ga_metrics.efficiency);
fprintf('Daily Pumping Cost ($)          : $%-15.2f $%.2f\n', pso_metrics.pump_cost, ga_metrics.pump_cost);
fprintf('Daily Generation Revenue ($)    : $%-15.2f $%.2f\n', pso_metrics.gen_revenue, ga_metrics.gen_revenue);
fprintf('Daily Net Profit ($)            : $%-15.2f $%.2f\n', pso_metrics.net_profit, ga_metrics.net_profit);

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('                  PEAK SHAVING PERFORMANCE\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Metric                              PSO              GA\n');
fprintf('────────────────────────────────────────────────────────────────────\n');
fprintf('Original Peak Load (MW)         : %-15.2f %.2f\n', max(Load), max(Load));
fprintf('Reduced Peak Load (MW)          : %-15.2f %.2f\n', pso_metrics.reduced_peak, ga_metrics.reduced_peak);
fprintf('Peak Reduction (MW)             : %-15.2f %.2f\n', pso_metrics.peak_reduction, ga_metrics.peak_reduction);
fprintf('Peak Reduction (%%)              : %-15.2f %.2f\n', pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct);
fprintf('Load Variance Reduction (%%)     : %-15.2f %.2f\n', pso_metrics.variance_reduction, ga_metrics.variance_reduction);

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('           PEAK THERMAL GENERATION REDUCTION (NEW)\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Metric                              PSO              GA\n');
fprintf('────────────────────────────────────────────────────────────────────\n');
fprintf('Thermal Generation Displaced     \n');
fprintf('  Per Day (MWh)                  : %-15.2f %.2f\n', PSO_Thermal_Displaced_MWh, GA_Thermal_Displaced_MWh);
fprintf('  Per Year (GWh)                 : %-15.2f %.2f\n', PSO_Thermal_Annual_MWh/1000, GA_Thermal_Annual_MWh/1000);
fprintf('Avg Thermal MW Reduction         \n');
fprintf('  During Peak Hours (MW)         : %-15.2f %.2f\n', PSO_Thermal_Peak_MW_Reduction, GA_Thermal_Peak_MW_Reduction);
fprintf('Peak Hours Covered               : %-15d %d hrs\n', Peak_Hours_Count, Peak_Hours_Count);
fprintf('Peaker Capacity Avoided (MW)     : %-15.2f %.2f\n', PSO_Peaker_Capacity_Avoided, GA_Peaker_Capacity_Avoided);
fprintf('[Note: Based on SCGT/oil peaker displacement, Egypt grid context]\n');
fprintf('[Physical limits applied: Max gen = %.0f MWh/day, RT eff = %.1f%%]\n', Max_Possible_Gen_MWh, RT_Efficiency*100);

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('              CO2 EMISSION REDUCTION ANALYSIS (NEW)\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Assumption: Peak plants = %.3f tCO2/MWh | Pumping grid = %.3f tCO2/MWh\n', ...
    Peak_Thermal_Emission_Factor, Night_Grid_Emission_Factor);
fprintf('────────────────────────────────────────────────────────────────────\n');
fprintf('Metric                              PSO              GA\n');
fprintf('────────────────────────────────────────────────────────────────────\n');
fprintf('CO2 Displaced (peak displaced)   \n');
fprintf('  Per Day (tCO2)                 : %-15.2f %.2f\n', PSO_CO2_Displaced, GA_CO2_Displaced);
fprintf('CO2 Added (pumping emissions)    \n');
fprintf('  Per Day (tCO2)                 : %-15.2f %.2f\n', PSO_CO2_Pumping, GA_CO2_Pumping);
fprintf('NET CO2 Saved                    \n');
fprintf('  Per Day (tCO2)                 : %-15.2f %.2f\n', PSO_CO2_Net_Saved, GA_CO2_Net_Saved);
fprintf('  Per Year (tCO2/yr)             : %-15.2f %.2f\n', PSO_CO2_Annual, GA_CO2_Annual);
fprintf('  Per Year (ktCO2/yr)            : %-15.4f %.4f\n', PSO_CO2_Annual/1000, GA_CO2_Annual/1000);
fprintf('CO2 Reduction vs No-PSH (%%)     : %-15.2f %.2f\n', ...
    PSO_CO2_Net_Saved/PSO_CO2_Displaced*100, GA_CO2_Net_Saved/GA_CO2_Displaced*100);
fprintf('[Equivalent trees saved/yr]      : %-15.0f %.0f\n', ...
    PSO_CO2_Annual/0.022, GA_CO2_Annual/0.022);  % 1 tree absorbs ~22 kg CO2/yr

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('                        OVERALL WINNER\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
if -gbest_cost_pso > -gbest_cost_ga
    eco_adv = ((-gbest_cost_pso)-(-gbest_cost_ga))/(-gbest_cost_ga)*100;
    fprintf('  PSO PERFORMS BETTER\n');
    fprintf('  Economic advantage : $%.2f/day (%.2f%% better)\n', (-gbest_cost_pso)-(-gbest_cost_ga), eco_adv);
    fprintf('  CO2 advantage      : %.2f tCO2/day more savings\n', PSO_CO2_Net_Saved - GA_CO2_Net_Saved);
else
    eco_adv = ((-gbest_cost_ga)-(-gbest_cost_pso))/(-gbest_cost_pso)*100;
    fprintf('  GA PERFORMS BETTER\n');
    fprintf('  Economic advantage : $%.2f/day (%.2f%% better)\n', (-gbest_cost_ga)-(-gbest_cost_pso), eco_adv);
    fprintf('  CO2 advantage      : %.2f tCO2/day more savings\n', GA_CO2_Net_Saved - PSO_CO2_Net_Saved);
end
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

%% ====================================================
% FIGURE 1: MASTER COMPARISON PLOT (Original + Updated)
% ====================================================
figure('Color','w','Position',[50 50 1600 950]);
sgtitle(sprintf('PSO vs GA COMPREHENSIVE OPTIMIZATION COMPARISON - %s Season', Current_Season_Name), ...
    'FontSize', 16, 'FontWeight', 'bold');

% 1. Convergence
subplot(3,3,1);
plot(1:pso_iterations, pso_history, '-', 'LineWidth', 2.5, 'Color', [0.2 0.4 0.8]);
hold on;
plot(1:ga_generations, ga_history, '-', 'LineWidth', 2.5, 'Color', [0.9 0.4 0.2]);
grid on;
xlabel('Iteration/Generation','FontSize',10,'FontWeight','bold');
ylabel('Best Cost ($)','FontSize',10,'FontWeight','bold');
title('Convergence Comparison','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northeast');

% 2. Solution Feasibility
subplot(3,3,2);
yyaxis left
plot(1:pso_iterations, pso_valid_count, '-', 'LineWidth', 2, 'Color', [0.2 0.6 0.8]);
ylabel('Valid Solutions (PSO)','FontSize',10,'FontWeight','bold');
ylim([0 pso_particles*1.1]);
yyaxis right
plot(1:ga_generations, ga_valid_count, '-', 'LineWidth', 2, 'Color', [0.9 0.5 0.2]);
ylabel('Valid Solutions (GA)','FontSize',10,'FontWeight','bold');
ylim([0 ga_population*1.1]);
grid on;
xlabel('Iteration/Generation','FontSize',10,'FontWeight','bold');
title('Solution Feasibility','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'southeast');

% 3. Economic Performance
subplot(3,3,3);
economic_metrics = [-gbest_cost_pso, -gbest_cost_ga; pso_metrics.net_profit, ga_metrics.net_profit];
b = bar(economic_metrics');
b(1).FaceColor = [0.2 0.4 0.8]; b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Final Cost', 'Net Profit'});
ylabel('Value ($/day)','FontSize',10,'FontWeight','bold');
title('Economic Performance','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on;

% 4. PSO Schedule
subplot(3,3,4);
yyaxis left
bar(hours, PSO_Pumping, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
ylabel('Pumping (MW)','FontSize',10,'FontWeight','bold');
ylim([0 Max_Pumping_Power*1.2]);
yyaxis right
bar(hours, -PSO_Generation, 'FaceColor', [0.9 0.4 0.2], 'EdgeColor', 'k');
ylabel('Generation (MW)','FontSize',10,'FontWeight','bold');
ylim([-Max_Generation_Power*1.2 0]);
xlabel('Hour','FontSize',10,'FontWeight','bold');
title('PSO Optimal Schedule','FontSize',11,'FontWeight','bold');
grid on; xticks(1:24);

% 5. GA Schedule
subplot(3,3,5);
yyaxis left
bar(hours, GA_Pumping, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
ylabel('Pumping (MW)','FontSize',10,'FontWeight','bold');
ylim([0 Max_Pumping_Power*1.2]);
yyaxis right
bar(hours, -GA_Generation, 'FaceColor', [0.9 0.4 0.2], 'EdgeColor', 'k');
ylabel('Generation (MW)','FontSize',10,'FontWeight','bold');
ylim([-Max_Generation_Power*1.2 0]);
xlabel('Hour','FontSize',10,'FontWeight','bold');
title('GA Optimal Schedule','FontSize',11,'FontWeight','bold');
grid on; xticks(1:24);

% 6. Peak Shaving
subplot(3,3,6);
pso_net_load = Load - PSO_Generation;
ga_net_load  = Load - GA_Generation;
plot(hours, Load, '-k', 'LineWidth', 2.5); hold on;
plot(hours, pso_net_load, '--', 'LineWidth', 2, 'Color', [0.2 0.4 0.8]);
plot(hours, ga_net_load, '--', 'LineWidth', 2, 'Color', [0.9 0.4 0.2]);
yline(max(Load), ':r', 'Original Peak', 'LineWidth', 1.5);
yline(pso_metrics.reduced_peak, ':b', sprintf('PSO: %.0f MW', pso_metrics.reduced_peak), 'LineWidth', 1.5);
yline(ga_metrics.reduced_peak, ':', 'Color', [0.9 0.4 0.2], ...
      'Label', sprintf('GA: %.0f MW', ga_metrics.reduced_peak), 'LineWidth', 1.5);
grid on;
xlabel('Hour','FontSize',10,'FontWeight','bold');
ylabel('Load (MW)','FontSize',10,'FontWeight','bold');
title('Peak Shaving Performance','FontSize',11,'FontWeight','bold');
legend('Original', 'PSO Net', 'GA Net', 'Location', 'northwest');

% 7. Energy Metrics
subplot(3,3,7);
energy_data = [pso_metrics.pump_total, ga_metrics.pump_total; ...
               pso_metrics.gen_total,  ga_metrics.gen_total; ...
               pso_metrics.efficiency, ga_metrics.efficiency];
b = bar(energy_data');
b(1).FaceColor = [0.2 0.4 0.8]; b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Pumping (MWh)', 'Generation (MWh)', 'Efficiency (%)'});
ylabel('Value','FontSize',10,'FontWeight','bold');
title('Energy Performance','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on; xtickangle(15);

% 8. Peak Management Metrics
subplot(3,3,8);
peak_data = [pso_metrics.peak_reduction, ga_metrics.peak_reduction; ...
             pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct; ...
             pso_metrics.variance_reduction, ga_metrics.variance_reduction];
b = bar(peak_data');
b(1).FaceColor = [0.2 0.4 0.8]; b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Reduction (MW)', 'Reduction (%)', 'Variance Red (%)'});
ylabel('Value','FontSize',10,'FontWeight','bold');
title('Peak Management Metrics','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on; xtickangle(15);

% 9. Overall Winner
subplot(3,3,9);
axis off;
if -gbest_cost_pso > -gbest_cost_ga
    winner = 'PSO'; winner_color = [0.2 0.4 0.8];
    advantage_pct = ((-gbest_cost_pso)-(-gbest_cost_ga))/(-gbest_cost_ga)*100;
else
    winner = 'GA'; winner_color = [0.9 0.4 0.2];
    advantage_pct = ((-gbest_cost_ga)-(-gbest_cost_pso))/(-gbest_cost_pso)*100;
end
text(0.5, 0.90, '🏆', 'FontSize', 50, 'HorizontalAlignment', 'center');
text(0.5, 0.75, sprintf('%s WINS!', winner), 'FontSize', 18, 'FontWeight', 'bold', ...
     'HorizontalAlignment', 'center', 'Color', winner_color);
text(0.5, 0.62, sprintf('Season: %s', Current_Season_Name), 'FontSize', 11, ...
     'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);
text(0.5, 0.52, sprintf('Economic Advantage: %.2f%%', advantage_pct), ...
     'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
text(0.5, 0.43, sprintf('Cost: $%.2f vs $%.2f/day', -gbest_cost_pso, -gbest_cost_ga), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');
text(0.5, 0.35, sprintf('Peak Reduction: %.1f%% vs %.1f%%', ...
     pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');
text(0.5, 0.27, sprintf('Efficiency: %.2f%% vs %.2f%%', ...
     pso_metrics.efficiency, ga_metrics.efficiency), 'FontSize', 10, 'HorizontalAlignment', 'center');
text(0.5, 0.19, sprintf('Net CO2 Saved: %.1f vs %.1f tCO2/day', PSO_CO2_Net_Saved, GA_CO2_Net_Saved), ...
     'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [0.1 0.5 0.2]);
text(0.5, 0.10, sprintf('Load Factor: %.2fx Base', Current_Season_Factor), ...
     'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
xlim([0 1]); ylim([0 1]);

%% ====================================================
% FIGURE 2: CO2 & THERMAL GENERATION REDUCTION PLOT
% ====================================================
figure('Color','w','Position',[80 80 1500 900]);
sgtitle(sprintf('CO_2 EMISSION REDUCTION & PEAK THERMAL GENERATION DISPLACEMENT\nEgypt PSH System - %s Season', ...
    Current_Season_Name), 'FontSize', 15, 'FontWeight', 'bold');

colors_pso = [0.2 0.4 0.8];
colors_ga  = [0.9 0.4 0.2];
colors_green = [0.1 0.6 0.2];

% --- PANEL 1: CO2 Breakdown Bar Chart ---
subplot(2,3,1);
co2_categories = {'CO2 Displaced\n(Peak Plants)', 'CO2 Added\n(Pumping)', 'NET CO2\nSaved'};
pso_co2_vals = [PSO_CO2_Displaced, PSO_CO2_Pumping, PSO_CO2_Net_Saved];
ga_co2_vals  = [GA_CO2_Displaced,  GA_CO2_Pumping,  GA_CO2_Net_Saved];
data_co2 = [pso_co2_vals; ga_co2_vals]';
b = bar(data_co2);
b(1).FaceColor = colors_pso; b(2).FaceColor = colors_ga;
set(gca, 'XTickLabel', {'CO2 Displaced', 'CO2 Pumping', 'Net CO2 Saved'});
ylabel('CO_2 (tCO_2/day)','FontSize',10,'FontWeight','bold');
title('CO_2 Emission Balance (Daily)','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on; xtickangle(15);
% Add value labels
for k = 1:3
    text(k-0.14, pso_co2_vals(k)+1, sprintf('%.1f', pso_co2_vals(k)), ...
         'HorizontalAlignment','center','FontSize',8,'FontWeight','bold','Color',colors_pso);
    text(k+0.14, ga_co2_vals(k)+1, sprintf('%.1f', ga_co2_vals(k)), ...
         'HorizontalAlignment','center','FontSize',8,'FontWeight','bold','Color',colors_ga);
end

% --- PANEL 2: Net CO2 Saved Hourly Profile ---
subplot(2,3,2);
% Hourly CO2 impact: generation hours save CO2, pumping hours add CO2
pso_hourly_co2 = zeros(1,24);
ga_hourly_co2  = zeros(1,24);
for h = 1:24
    if Period(h) == "PEAK"
        pso_hourly_co2(h) = PSO_Generation(h) * Peak_Thermal_Emission_Factor;
        ga_hourly_co2(h)  = GA_Generation(h)  * Peak_Thermal_Emission_Factor;
    else
        pso_hourly_co2(h) = -PSO_Pumping(h) * Night_Grid_Emission_Factor;
        ga_hourly_co2(h)  = -GA_Pumping(h)  * Night_Grid_Emission_Factor;
    end
end
bar(hours, pso_hourly_co2, 'FaceColor', colors_pso, 'EdgeColor','k','FaceAlpha',0.7);
hold on;
bar(hours, ga_hourly_co2, 'FaceColor', colors_ga, 'EdgeColor','k','FaceAlpha',0.5);
yline(0, '-k', 'LineWidth', 1.5);
xlabel('Hour of Day','FontSize',10,'FontWeight','bold');
ylabel('CO_2 Impact (tCO_2/hr)','FontSize',10,'FontWeight','bold');
title('Hourly CO_2 Impact Profile','FontSize',11,'FontWeight','bold');
legend('PSO (+saved / -added)', 'GA (+saved / -added)', 'Location', 'northwest');
grid on; xticks(1:24);
text(0.5, 0.05, 'Positive = CO2 Saved | Negative = CO2 Added', ...
     'Units','normalized','FontSize',8,'Color',[0.4 0.4 0.4]);

% --- PANEL 3: Annual CO2 Savings Comparison ---
subplot(2,3,3);
annual_data = [PSO_CO2_Annual/1000, GA_CO2_Annual/1000];
b = bar(annual_data, 'FaceColor', 'flat', 'EdgeColor','k','LineWidth',1.2);
b.CData(1,:) = colors_pso; b.CData(2,:) = colors_ga;
set(gca,'XTickLabel', {'PSO', 'GA'});
ylabel('Annual Net CO_2 Saved (ktCO_2/yr)','FontSize',10,'FontWeight','bold');
title('Annual CO_2 Emission Reduction','FontSize',11,'FontWeight','bold');
grid on;
text(1, PSO_CO2_Annual/1000 + 0.02, sprintf('%.3f ktCO_2/yr\n%.0f tCO_2/yr', ...
     PSO_CO2_Annual/1000, PSO_CO2_Annual), 'HorizontalAlignment','center', ...
     'FontSize',9,'FontWeight','bold','Color',colors_pso);
text(2, GA_CO2_Annual/1000 + 0.02, sprintf('%.3f ktCO_2/yr\n%.0f tCO_2/yr', ...
     GA_CO2_Annual/1000, GA_CO2_Annual), 'HorizontalAlignment','center', ...
     'FontSize',9,'FontWeight','bold','Color',colors_ga);

% --- PANEL 4: Thermal Generation Displaced (Hourly) ---
subplot(2,3,4);
area(hours, PSO_Generation, 'FaceColor', colors_pso, 'EdgeColor','k','FaceAlpha',0.6);
hold on;
area(hours, GA_Generation, 'FaceColor', colors_ga, 'EdgeColor','k','FaceAlpha',0.5);
xlabel('Hour of Day','FontSize',10,'FontWeight','bold');
ylabel('Thermal Generation Displaced (MW)','FontSize',10,'FontWeight','bold');
title('Hourly Peak Thermal Displacement','FontSize',11,'FontWeight','bold');
legend('PSO Displaced', 'GA Displaced', 'Location', 'northwest');
grid on; xticks(1:24);
% Shade peak periods
for h = 1:24
    if Period(h) == "PEAK"
        xpatch = [h-0.5, h+0.5, h+0.5, h-0.5];
        ypatch = [0, 0, Max_Generation_Power*1.05, Max_Generation_Power*1.05];
        patch(xpatch, ypatch, [1 1 0.7], 'FaceAlpha',0.15,'EdgeColor','none');
    end
end
ylim([0 Max_Generation_Power*1.1]);
text(0.5, 0.95, 'Yellow bands = PEAK hours', 'Units','normalized', ...
     'FontSize',8,'Color',[0.6 0.5 0],'HorizontalAlignment','center');

% --- PANEL 5: Cumulative CO2 Saving Profile ---
subplot(2,3,5);
pso_cumulative_co2 = cumsum(pso_hourly_co2);
ga_cumulative_co2  = cumsum(ga_hourly_co2);
plot(hours, pso_cumulative_co2, '-o', 'LineWidth', 2.5, 'MarkerSize', 6, 'Color', colors_pso);
hold on;
plot(hours, ga_cumulative_co2, '-s', 'LineWidth', 2.5, 'MarkerSize', 6, 'Color', colors_ga);
yline(0, '--k', 'Break-even', 'LineWidth', 1.5);
fill([hours, fliplr(hours)], [pso_cumulative_co2, zeros(1,24)], colors_pso, 'FaceAlpha',0.1,'EdgeColor','none');
fill([hours, fliplr(hours)], [ga_cumulative_co2, zeros(1,24)], colors_ga, 'FaceAlpha',0.1,'EdgeColor','none');
xlabel('Hour of Day','FontSize',10,'FontWeight','bold');
ylabel('Cumulative CO_2 (tCO_2)','FontSize',10,'FontWeight','bold');
title('Cumulative CO_2 Savings Profile','FontSize',11,'FontWeight','bold');
legend('PSO Cumulative', 'GA Cumulative', 'Location', 'northwest');
grid on; xticks(1:24);
% Final daily total annotation
text(24, pso_cumulative_co2(end), sprintf(' %.1f t', pso_cumulative_co2(end)), ...
     'FontSize', 9, 'FontWeight','bold','Color',colors_pso);
text(24, ga_cumulative_co2(end)-3, sprintf(' %.1f t', ga_cumulative_co2(end)), ...
     'FontSize', 9, 'FontWeight','bold','Color',colors_ga);

% --- PANEL 6: Comprehensive Environmental Summary ---
subplot(2,3,6);
axis off;
text(0.5, 0.98, 'ENVIRONMENTAL IMPACT SUMMARY', 'FontSize', 12, 'FontWeight','bold', ...
     'HorizontalAlignment','center', 'Color', colors_green);

y = 0.88;
dy = 0.085;

% Header
text(0.02, y, 'Metric', 'FontSize', 9.5, 'FontWeight','bold'); 
text(0.50, y, 'PSO', 'FontSize', 9.5, 'FontWeight','bold', 'Color', colors_pso);
text(0.75, y, 'GA', 'FontSize', 9.5, 'FontWeight','bold', 'Color', colors_ga);
y = y - 0.02;
line([0.02 0.98], [y y], 'Color',[0.7 0.7 0.7],'LineWidth',1);

% Rows
rows = {
    'CO2 Displaced/day (t)',      sprintf('%.2f', PSO_CO2_Displaced),      sprintf('%.2f', GA_CO2_Displaced);
    'CO2 from Pumping/day (t)',   sprintf('%.2f', PSO_CO2_Pumping),        sprintf('%.2f', GA_CO2_Pumping);
    'Net CO2 Saved/day (t)',      sprintf('%.2f', PSO_CO2_Net_Saved),      sprintf('%.2f', GA_CO2_Net_Saved);
    'Net CO2 Saved/yr (t)',       sprintf('%.1f', PSO_CO2_Annual),         sprintf('%.1f', GA_CO2_Annual);
    'Equiv. Trees/yr',            sprintf('%.0f', PSO_CO2_Annual/0.022),   sprintf('%.0f', GA_CO2_Annual/0.022);
    'Thermal Displaced/day (MWh)',sprintf('%.2f', PSO_Thermal_Displaced_MWh), sprintf('%.2f', GA_Thermal_Displaced_MWh);
    'Thermal Displaced/yr (GWh)', sprintf('%.3f', PSO_Thermal_Annual_MWh/1000), sprintf('%.3f', GA_Thermal_Annual_MWh/1000);
    'Avg Peak Thermal Red (MW)',  sprintf('%.2f', PSO_Thermal_Peak_MW_Reduction), sprintf('%.2f', GA_Thermal_Peak_MW_Reduction);
    'Peaker Capacity Avoided (MW)',sprintf('%.2f', PSO_Peaker_Capacity_Avoided), sprintf('%.2f', GA_Peaker_Capacity_Avoided);
};

for r = 1:size(rows,1)
    y = y - dy;
    clr_row = iif(mod(r,2)==0, [0.95 0.95 0.95], [1 1 1]);
    fill([0 1 1 0], [y-0.006 y-0.006 y+0.07 y+0.07], clr_row, 'EdgeColor','none');
    text(0.02, y+0.01, rows{r,1}, 'FontSize', 8.5);
    text(0.52, y+0.01, rows{r,2}, 'FontSize', 8.5, 'FontWeight','bold','Color', colors_pso);
    text(0.76, y+0.01, rows{r,3}, 'FontSize', 8.5, 'FontWeight','bold','Color', colors_ga);
end

xlim([0 1]); ylim([0 1]);

%% ====================================================
% FIGURE 3: SEASONAL COMPARISON
% ====================================================
figure('Color','w','Position',[100 100 1400 700]);
sgtitle('SEASONAL IMPACT ON PSH OPERATIONS - EGYPT', 'FontSize', 16, 'FontWeight', 'bold');

seasonal_loads = zeros(4, 24);
for s = 1:4
    seasonal_loads(s,:) = Base_Load * Season_Factors(s);
end

colors_s = [0.9 0.2 0.2; 0.9 0.6 0.2; 0.2 0.6 0.9; 0.4 0.8 0.4];

subplot(2,3,1);
for s = 1:4
    plot(hours, seasonal_loads(s,:), '-', 'LineWidth', 2, 'Color', colors_s(s,:), 'DisplayName', Season_Names(s));
    hold on;
end
grid on; xlabel('Hour','FontSize',10,'FontWeight','bold');
ylabel('Load (MW)','FontSize',10,'FontWeight','bold');
title('Seasonal Load Profiles','FontSize',11,'FontWeight','bold'); legend('Location', 'northwest');

subplot(2,3,2);
seasonal_peaks = max(seasonal_loads, [], 2);
b = bar(seasonal_peaks, 'FaceColor', 'flat');
for s = 1:4; b.CData(s,:) = colors_s(s,:); end
set(gca, 'XTickLabel', Season_Names);
ylabel('Peak Load (MW)','FontSize',10,'FontWeight','bold');
title('Seasonal Peak Demands','FontSize',11,'FontWeight','bold'); grid on;
for s = 1:4
    text(s, seasonal_peaks(s)+500, sprintf('%.0f MW', seasonal_peaks(s)), ...
         'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
end

subplot(2,3,3);
b = bar(Season_Factors, 'FaceColor', 'flat');
for s = 1:4; b.CData(s,:) = colors_s(s,:); end
set(gca, 'XTickLabel', Season_Names);
ylabel('Load Multiplier','FontSize',10,'FontWeight','bold');
title('Seasonal Load Factors','FontSize',11,'FontWeight','bold');
yline(1, '--k', 'Base Load', 'LineWidth', 1.5); grid on;
for s = 1:4
    text(s, Season_Factors(s)+0.05, sprintf('%.2fx', Season_Factors(s)), ...
         'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
end

subplot(2,3,4);
months = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
avg_temps = [18,19,22,26,30,33,35,35,32,28,23,19];
plot(1:12, avg_temps, '-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0.9 0.3 0.2]);
hold on;
patch([1 2 2 1],[0 0 40 40], colors_s(3,:),'FaceAlpha',0.1,'EdgeColor','none');
patch([3 5 5 3],[0 0 40 40], colors_s(4,:),'FaceAlpha',0.1,'EdgeColor','none');
patch([6 8 8 6],[0 0 40 40], colors_s(1,:),'FaceAlpha',0.1,'EdgeColor','none');
patch([9 11 11 9],[0 0 40 40], colors_s(2,:),'FaceAlpha',0.1,'EdgeColor','none');
grid on;
xlabel('Month','FontSize',10,'FontWeight','bold'); ylabel('Temperature (°C)','FontSize',10,'FontWeight','bold');
title('Egypt Monthly Temperature Profile','FontSize',11,'FontWeight','bold');
set(gca,'XTick',1:12,'XTickLabel',months); xtickangle(45); ylim([0 40]);

subplot(2,3,5);
psh_utilization = [95, 70, 45, 65];
b = bar(psh_utilization, 'FaceColor', 'flat');
for s = 1:4; b.CData(s,:) = colors_s(s,:); end
set(gca,'XTickLabel', Season_Names);
ylabel('PSH Utilization (%)','FontSize',10,'FontWeight','bold');
title('Expected PSH Capacity Utilization','FontSize',11,'FontWeight','bold');
grid on; ylim([0 100]);
for s = 1:4
    text(s, psh_utilization(s)+3, sprintf('%.0f%%', psh_utilization(s)), ...
         'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
end

subplot(2,3,6);
axis off;
text(0.5,0.95,'SEASONAL OPERATING RECOMMENDATIONS','FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
y_pos = 0.80; line_height = 0.18;
text(0.05,y_pos,'☀️ SUMMER (Jun-Aug)','FontSize',11,'FontWeight','bold','Color',colors_s(1,:));
text(0.08,y_pos-0.05,'• Maximum PSH deployment','FontSize',9);
text(0.08,y_pos-0.09,'• Critical for grid stability','FontSize',9);
text(0.08,y_pos-0.13,'• Highest revenue potential','FontSize',9);
y_pos = y_pos - line_height;
text(0.05,y_pos,'🍂 AUTUMN (Sep-Nov)','FontSize',11,'FontWeight','bold','Color',colors_s(2,:));
text(0.08,y_pos-0.05,'• Moderate PSH operations','FontSize',9);
text(0.08,y_pos-0.09,'• Standard peak shaving','FontSize',9);
y_pos = y_pos - line_height;
text(0.05,y_pos,'❄️ WINTER (Dec-Feb)','FontSize',11,'FontWeight','bold','Color',colors_s(3,:));
text(0.08,y_pos-0.05,'• Reduced PSH demand','FontSize',9);
text(0.08,y_pos-0.09,'• Ideal for maintenance','FontSize',9);
y_pos = y_pos - line_height;
text(0.05,y_pos,'🌸 SPRING (Mar-May)','FontSize',11,'FontWeight','bold','Color',colors_s(4,:));
text(0.08,y_pos-0.05,'• Increasing PSH utilization','FontSize',9);
text(0.08,y_pos-0.09,'• Prepare for summer peaks','FontSize',9);
xlim([0 1]); ylim([0 1]);

%% ====================================================
% SAVE RESULTS TO EXCEL
% ====================================================
fprintf('\n================ SAVING RESULTS ================\n');

T_Comparison = table(...
    {'Final Cost ($/day)';'Computation Time (sec)';'Total Pumping (MWh)';...
     'Total Generation (MWh)';'Round-Trip Efficiency (%)';'Peak Reduction (MW)';...
     'Peak Reduction (%)';'Variance Reduction (%)';'Daily Net Profit ($)';...
     'Energy Balance Error (MWh)';...
     'CO2 Displaced/day (tCO2)';'CO2 from Pumping/day (tCO2)';...
     'Net CO2 Saved/day (tCO2)';'Net CO2 Saved/yr (tCO2)';...
     'Thermal Displaced/day (MWh)';'Thermal Displaced/yr (GWh)';...
     'Avg Peak Thermal Reduction (MW)';'Peaker Capacity Avoided (MW)'}, ...
    [-gbest_cost_pso; pso_time; pso_metrics.pump_total; pso_metrics.gen_total;...
     pso_metrics.efficiency; pso_metrics.peak_reduction; pso_metrics.peak_reduction_pct;...
     pso_metrics.variance_reduction; pso_metrics.net_profit; pso_metrics.balance_error;...
     PSO_CO2_Displaced; PSO_CO2_Pumping; PSO_CO2_Net_Saved; PSO_CO2_Annual;...
     PSO_Thermal_Displaced_MWh; PSO_Thermal_Annual_MWh/1000;...
     PSO_Thermal_Peak_MW_Reduction; PSO_Peaker_Capacity_Avoided], ...
    [-gbest_cost_ga; ga_time; ga_metrics.pump_total; ga_metrics.gen_total;...
     ga_metrics.efficiency; ga_metrics.peak_reduction; ga_metrics.peak_reduction_pct;...
     ga_metrics.variance_reduction; ga_metrics.net_profit; ga_metrics.balance_error;...
     GA_CO2_Displaced; GA_CO2_Pumping; GA_CO2_Net_Saved; GA_CO2_Annual;...
     GA_Thermal_Displaced_MWh; GA_Thermal_Annual_MWh/1000;...
     GA_Thermal_Peak_MW_Reduction; GA_Peaker_Capacity_Avoided], ...
    'VariableNames', {'Metric', 'PSO', 'GA'});

T_Seasonal = table(Season_Names', Season_Factors', max(seasonal_loads,[],2), [95;70;45;65], ...
    'VariableNames', {'Season','Load_Factor','Peak_Load_MW','PSH_Utilization_Pct'});

filename = sprintf('Egypt_PSH_PSO_vs_GA_%s_Season.xlsx', Current_Season_Name);
writetable(T_Comparison, filename, 'Sheet', 'Comparison_Summary');
writetable(T_Seasonal, filename, 'Sheet', 'Seasonal_Analysis');
fprintf('Results saved to: %s\n', filename);
fprintf('===========================================================\n\n');
fprintf('====================================================\n');
fprintf(' OPTIMIZATION COMPLETED | Season: %s\n', Current_Season_Name);
fprintf(' Figures Generated: 3 (Main | CO2+Thermal | Seasonal)\n');
fprintf('====================================================\n');

%% ====================================================
% SUPPORTING FUNCTIONS
% ====================================================

function [cost, valid, metrics] = evaluate_psh_schedule_corrected(pump, gen, Load, Period, ...
    Max_Pump, Max_Gen, Pump_Eff, Gen_Eff, Res_Cap, Init_SOC, Min_SOC, Max_SOC, ...
    Off_Peak_Price, Peak_Price)
    reservoir = Res_Cap * Init_SOC;
    valid = true;
    total_pump_cost = 0; total_gen_revenue = 0;
    peak_demand_reduction = 0;
    pump_energy_total = 0; gen_energy_total = 0;
    pump_hydraulic_total = 0; gen_hydraulic_total = 0;
    for h = 1:24
        if Period(h) == "OFF-PEAK", gen(h) = 0; else, pump(h) = 0; end
        if pump(h) > 0
            available_space = (Res_Cap * Max_SOC) - reservoir;
            actual_pump = min([pump(h), Max_Pump, available_space/Pump_Eff]);
            actual_pump = max(0, actual_pump);
            energy_stored = actual_pump * Pump_Eff;
            reservoir = reservoir + energy_stored;
            total_pump_cost = total_pump_cost + actual_pump * Off_Peak_Price;
            pump_energy_total = pump_energy_total + actual_pump;
            pump_hydraulic_total = pump_hydraulic_total + energy_stored;
        end
        if gen(h) > 0
            available_energy = reservoir - (Res_Cap * Min_SOC);
            actual_gen = min([gen(h), Max_Gen, available_energy * Gen_Eff]);
            actual_gen = max(0, actual_gen);
            energy_released = actual_gen / Gen_Eff;
            reservoir = reservoir - energy_released;
            total_gen_revenue = total_gen_revenue + actual_gen * Peak_Price;
            gen_energy_total = gen_energy_total + actual_gen;
            gen_hydraulic_total = gen_hydraulic_total + energy_released;
            peak_demand_reduction = peak_demand_reduction + actual_gen;
        end
        if reservoir < Res_Cap * Min_SOC - 0.1 || reservoir > Res_Cap * Max_SOC + 0.1
            valid = false;
        end
    end
    if gen_hydraulic_total > pump_hydraulic_total * 1.01, valid = false; end
    if pump_energy_total > 0
        if (gen_energy_total/pump_energy_total) > Pump_Eff*Gen_Eff*1.01, valid = false; end
    end
    peak_benefit_value = peak_demand_reduction * 10;
    cost = -(total_gen_revenue - total_pump_cost + peak_benefit_value);
    if ~valid, cost = cost + 1e9; end
    metrics.pump_total = pump_energy_total;
    metrics.gen_total = gen_energy_total;
    metrics.peak_reduction = peak_demand_reduction;
    metrics.efficiency = gen_energy_total / max(pump_energy_total, 0.001) * 100;
end

function [metrics] = evaluate_detailed_metrics(pump, gen, Load, Period, ...
    Max_Pump, Max_Gen, Pump_Eff, Gen_Eff, Res_Cap, Init_SOC, Min_SOC, Max_SOC, ...
    Off_Peak_Price, Peak_Price)
    reservoir = Res_Cap * Init_SOC;
    total_pump_cost = 0; total_gen_revenue = 0;
    pump_energy_total = 0; gen_energy_total = 0;
    pump_hydraulic_total = 0; gen_hydraulic_total = 0;
    net_load = zeros(1, 24);
    for h = 1:24
        if Period(h) == "OFF-PEAK", gen(h) = 0; else, pump(h) = 0; end
        if pump(h) > 0
            available_space = (Res_Cap * Max_SOC) - reservoir;
            actual_pump = min([pump(h), Max_Pump, available_space/Pump_Eff]);
            actual_pump = max(0, actual_pump);
            energy_stored = actual_pump * Pump_Eff;
            reservoir = reservoir + energy_stored;
            total_pump_cost = total_pump_cost + actual_pump * Off_Peak_Price;
            pump_energy_total = pump_energy_total + actual_pump;
            pump_hydraulic_total = pump_hydraulic_total + energy_stored;
        end
        if gen(h) > 0
            available_energy = reservoir - (Res_Cap * Min_SOC);
            actual_gen = min([gen(h), Max_Gen, available_energy * Gen_Eff]);
            actual_gen = max(0, actual_gen);
            energy_released = actual_gen / Gen_Eff;
            reservoir = reservoir - energy_released;
            total_gen_revenue = total_gen_revenue + actual_gen * Peak_Price;
            gen_energy_total = gen_energy_total + actual_gen;
            gen_hydraulic_total = gen_hydraulic_total + energy_released;
            net_load(h) = Load(h) - actual_gen;
        else
            net_load(h) = Load(h);
        end
    end
    metrics.pump_total = pump_energy_total;
    metrics.gen_total = gen_energy_total;
    metrics.pump_cost = total_pump_cost;
    metrics.gen_revenue = total_gen_revenue;
    metrics.net_profit = total_gen_revenue - total_pump_cost;
    metrics.efficiency = (gen_energy_total / max(pump_energy_total, 0.001)) * 100;
    metrics.balance_error = pump_hydraulic_total - gen_hydraulic_total - (reservoir - Res_Cap * Init_SOC);
    original_peak = max(Load);
    reduced_peak = max(net_load);
    metrics.reduced_peak = reduced_peak;
    metrics.peak_reduction = original_peak - reduced_peak;
    metrics.peak_reduction_pct = (metrics.peak_reduction / original_peak) * 100;
    original_variance = var(Load);
    net_variance = var(net_load);
    metrics.variance_reduction = ((original_variance - net_variance) / original_variance) * 100;
end

function parent = tournament_selection(population, fitness, tournament_size)
    pop_size = size(population, 1);
    tournament_idx = randperm(pop_size, tournament_size);
    [~, winner_idx] = min(fitness(tournament_idx));
    parent = population(tournament_idx(winner_idx), :);
end

function offspring = crossover(parent1, parent2)
    n_vars = length(parent1);
    crossover_point = randi([1, n_vars-1]);
    offspring = [parent1(1:crossover_point), parent2(crossover_point+1:end)];
end

function offspring = mutate(offspring, lb, ub, mutation_rate)
    n_vars = length(offspring);
    for i = 1:n_vars
        if rand < mutation_rate
            offspring(i) = lb(i) + (ub(i) - lb(i)) * rand;
        end
    end
end

function result = iif(condition, true_val, false_val)
    if condition, result = true_val; else, result = false_val; end
end