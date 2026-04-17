clc;
clear;
close all;

fprintf('====================================================\n');
fprintf(' EGYPT PSH SYSTEM - PSO vs GA OPTIMIZATION COMPARISON\n');
fprintf(' WITH SEASONAL ANALYSIS\n');
fprintf('====================================================\n\n');

%% -----------------------------
% SEASONAL CONFIGURATION FOR EGYPT
% -----------------------------
fprintf('================ SEASONAL ANALYSIS FOR EGYPT ================\n');

% Define seasons for Egypt (Northern Hemisphere - Mediterranean/Desert Climate)
% Summer (June-August): Extreme heat, very high AC demand - PEAK SEASON
% Autumn (September-November): Moderate, decreasing demand
% Winter (December-February): Mild, heating in some areas - MODERATE SEASON  
% Spring (March-May): Pleasant, increasing demand

% User can select current season for analysis
fprintf('Egypt Seasonal Characteristics:\n');
fprintf('1. Summer (Jun-Aug)   : PEAK SEASON - Extreme heat, high AC demand\n');
fprintf('2. Autumn (Sep-Nov)   : MODERATE SEASON - Transitional period\n');
fprintf('3. Winter (Dec-Feb)   : LOW SEASON - Mild temperatures, lower demand\n');
fprintf('4. Spring (Mar-May)   : MODERATE SEASON - Pleasant weather\n\n');

% Set current season (1=Summer, 2=Autumn, 3=Winter, 4=Spring)
Current_Season = 1;  % Default: Summer (highest demand)

Season_Names = ["Summer", "Autumn", "Winter", "Spring"];
Season_Factors = [1.35, 1.10, 0.85, 1.05];  % Load multipliers for each season
Season_Descriptions = ["PEAK - Extreme Heat & AC", "MODERATE - Transitional", ...
                       "LOW - Mild Weather", "MODERATE - Pleasant"];

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

% Night OFF-PEAK (12 AM – 6 AM)
Base_Load(1:6) = 18000 + 500*sin(linspace(0,pi,6));

% Morning PEAK (6 AM – 11 AM)
Base_Load(7:11) = 25500 + 7500*sin(linspace(0,pi,5));

% Midday OFF-PEAK (11 AM – 6 PM)
Base_Load(12:17) = linspace(30500,18000,6);

% Evening PEAK (6 PM – 11 PM)
Base_Load(18:23) = 24000 + 14000*sin(linspace(0,pi,6));

% Late Night OFF-PEAK
Base_Load(24) = 24000;

Base_Load = round(Base_Load);

% Apply seasonal factor
Load = round(Base_Load * Current_Season_Factor);

fprintf('================ LOAD PROFILE INFORMATION ================\n');
fprintf('Base Load Range       : %d - %d MW\n', min(Base_Load), max(Base_Load));
fprintf('Seasonal Load Range   : %d - %d MW\n', min(Load), max(Load));
fprintf('Seasonal Increase     : %.1f%% over base load\n', (Current_Season_Factor-1)*100);
fprintf('===========================================================\n\n');

%% -----------------------------
% PEAK / OFF-PEAK IDENTIFICATION WITH SEASONAL CONTEXT
% -----------------------------
Period = strings(1,24);
for h = 1:24
    if (h >= 7 && h <= 11) || (h >= 18 && h <= 23)
        Period(h) = "PEAK";
    else
        Period(h) = "OFF-PEAK";
    end
end

fprintf('================ PEAK/OFF-PEAK PERIOD IDENTIFICATION ================\n');
fprintf('Daily Pattern (applies to all seasons):\n');
fprintf('  OFF-PEAK Hours: 12 AM - 6 AM  (Hours 1-6)\n');
fprintf('  PEAK Hours:     6 AM - 11 AM  (Hours 7-11)\n');
fprintf('  OFF-PEAK Hours: 11 AM - 6 PM  (Hours 12-17)\n');
fprintf('  PEAK Hours:     6 PM - 11 PM  (Hours 18-23)\n');
fprintf('  OFF-PEAK Hours: 11 PM - 12 AM (Hour 24)\n\n');

fprintf('SEASONAL CONTEXT FOR EGYPT:\n');
fprintf('─────────────────────────────────────────────────────────────────────\n');
fprintf('Season     │ Period        │ Characteristics\n');
fprintf('─────────────────────────────────────────────────────────────────────\n');
fprintf('SUMMER     │ Jun-Aug       │ ⚠️  CRITICAL PEAK SEASON\n');
fprintf('(Current)  │               │ • Extreme heat (40-45°C)\n');
fprintf('           │               │ • Maximum AC demand (residential & commercial)\n');
fprintf('           │               │ • Peak hours: 12 PM - 11 PM (extended)\n');
fprintf('           │               │ • Load Factor: %.2f (%.0f%% above base)\n', ...
    Season_Factors(1), (Season_Factors(1)-1)*100);
fprintf('           │               │ • Grid stress: VERY HIGH\n');
fprintf('─────────────────────────────────────────────────────────────────────\n');
fprintf('AUTUMN     │ Sep-Nov       │ 📊 MODERATE DEMAND SEASON\n');
fprintf('           │               │ • Cooling temperatures (25-35°C)\n');
fprintf('           │               │ • Decreasing AC usage\n');
fprintf('           │               │ • Standard peak hours\n');
fprintf('           │               │ • Load Factor: %.2f (%.0f%% above base)\n', ...
    Season_Factors(2), (Season_Factors(2)-1)*100);
fprintf('           │               │ • Grid stress: MODERATE\n');
fprintf('─────────────────────────────────────────────────────────────────────\n');
fprintf('WINTER     │ Dec-Feb       │ ✓  LOW DEMAND SEASON\n');
fprintf('           │               │ • Mild weather (15-25°C)\n');
fprintf('           │               │ • Minimal cooling/heating\n');
fprintf('           │               │ • Reduced evening peaks\n');
fprintf('           │               │ • Load Factor: %.2f (%.0f%% below base)\n', ...
    Season_Factors(3), (Season_Factors(3)-1)*100);
fprintf('           │               │ • Grid stress: LOW\n');
fprintf('─────────────────────────────────────────────────────────────────────\n');
fprintf('SPRING     │ Mar-May       │ 📊 MODERATE DEMAND SEASON\n');
fprintf('           │               │ • Pleasant weather (20-30°C)\n');
fprintf('           │               │ • Increasing AC usage toward summer\n');
fprintf('           │               │ • Standard peak hours\n');
fprintf('           │               │ • Load Factor: %.2f (%.0f%% above base)\n', ...
    Season_Factors(4), (Season_Factors(4)-1)*100);
fprintf('           │               │ • Grid stress: MODERATE\n');
fprintf('─────────────────────────────────────────────────────────────────────\n\n');

fprintf('CURRENT SEASON IMPACT ON PSH OPERATIONS:\n');
fprintf('Season: %s (%s)\n', Current_Season_Name, Current_Season_Desc);
fprintf('Expected PSH Utilization: ');
if Current_Season == 1  % Summer
    fprintf('MAXIMUM - Critical for peak shaving\n');
    fprintf('• PSH generation most valuable during extreme peaks\n');
    fprintf('• High arbitrage opportunities (large price spread)\n');
    fprintf('• Critical grid support during heat waves\n');
elseif Current_Season == 3  % Winter
    fprintf('MINIMUM - Lower grid stress\n');
    fprintf('• PSH generation less critical\n');
    fprintf('• Lower arbitrage opportunities\n');
    fprintf('• Good season for maintenance\n');
else  % Autumn/Spring
    fprintf('MODERATE - Standard operations\n');
    fprintf('• Normal PSH cycling operations\n');
    fprintf('• Moderate arbitrage opportunities\n');
    fprintf('• Standard grid support\n');
end
fprintf('===========================================================\n\n');

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
fprintf('Current Season: %s\n\n', Current_Season_Name);
fprintf('Maximum Peak Load       : %d MW\n', Max_Peak_Load);
fprintf('Average Peak Load       : %.2f MW\n', Avg_Peak_Load);
fprintf('Total Peak Duration     : %d hours\n', Peak_Duration);
fprintf('Maximum Ramp-Up Rate    : %d MW/hour\n', Max_Ramp_Up);
fprintf('Maximum Ramp-Down Rate  : %d MW/hour\n', Max_Ramp_Down);
fprintf('\nSeasonal Comparison:\n');
for s = 1:4
    seasonal_peak = max(Base_Load * Season_Factors(s));
    fprintf('  %s Peak: %d MW\n', Season_Names(s), round(seasonal_peak));
end
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

% Electricity Prices (adjusted for season if needed)
Off_Peak_Price = 30;                  % $/MWh
Peak_Price = 120;                     % $/MWh

% Apply seasonal price adjustment for summer
if Current_Season == 1  % Summer
    Peak_Price = Peak_Price * 1.2;  % 20% higher peak prices in summer
    fprintf('⚠️  Summer peak price adjustment applied (+20%%)\n');
end

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
% OPTIMIZATION SETUP - COMMON PARAMETERS
% ====================================================

% Decision variables: [Pumping_Power(1:24), Generation_Power(1:24)]
n_vars = 48;

% Initialize bounds with period constraints
lb = zeros(1, n_vars);
ub = zeros(1, n_vars);

for h = 1:24
    if Period(h) == "OFF-PEAK"
        ub(h) = Max_Pumping_Power;      % Can pump during off-peak
        ub(h+24) = 0;                   % Cannot generate during off-peak
    else
        ub(h) = 0;                      % Cannot pump during peak
        ub(h+24) = Max_Generation_Power; % Can generate during peak
    end
end

%% ====================================================
% OPTIMIZATION 1: PARTICLE SWARM OPTIMIZATION (PSO)
% ====================================================
fprintf('\n================ PSO OPTIMIZATION STARTED ================\n');
fprintf('Optimizing pumping/generation schedule using PSO...\n');

% PSO Parameters
pso_particles = 50;
pso_iterations = 200;
w = 0.7;           % Inertia weight
c1 = 1.5;          % Cognitive parameter
c2 = 1.5;          % Social parameter

% Initialize particles
particles = lb + (ub - lb) .* rand(pso_particles, n_vars);
velocities = zeros(pso_particles, n_vars);
pbest = particles;
pbest_cost = inf(pso_particles, 1);
gbest_pso = particles(1,:);
gbest_cost_pso = inf;

% PSO Optimization Loop
pso_history = zeros(pso_iterations, 1);
pso_valid_count = zeros(pso_iterations, 1);
pso_time_start = tic;

for iter = 1:pso_iterations
    valid_solutions = 0;
    
    for p = 1:pso_particles
        % Extract pumping and generation schedules
        pump_sched = particles(p, 1:24);
        gen_sched = particles(p, 25:48);
        
        % Evaluate fitness (objective function)
        [cost, valid, ~] = evaluate_psh_schedule_corrected(pump_sched, gen_sched, Load, Period, ...
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
            if cost < gbest_cost_pso
                gbest_cost_pso = cost;
                gbest_pso = particles(p,:);
            end
        end
    end
    
    % Update velocities and positions
    for p = 1:pso_particles
        r1 = rand(1, n_vars);
        r2 = rand(1, n_vars);
        
        velocities(p,:) = w * velocities(p,:) + ...
                         c1 * r1 .* (pbest(p,:) - particles(p,:)) + ...
                         c2 * r2 .* (gbest_pso - particles(p,:));
        
        particles(p,:) = particles(p,:) + velocities(p,:);
        
        % Enforce bounds
        particles(p,:) = max(lb, min(ub, particles(p,:)));
    end
    
    pso_history(iter) = gbest_cost_pso;
    pso_valid_count(iter) = valid_solutions;
    
    if mod(iter, 40) == 0
        fprintf('PSO Iteration %d/%d - Best Cost: $%.2f - Valid Solutions: %d/%d\n', ...
            iter, pso_iterations, gbest_cost_pso, valid_solutions, pso_particles);
    end
end

pso_time = toc(pso_time_start);

% Extract PSO optimal schedule
PSO_Pumping = gbest_pso(1:24);
PSO_Generation = gbest_pso(25:48);

fprintf('\n✅ PSO OPTIMIZATION COMPLETED\n');
fprintf('Final Best Cost: $%.2f/day\n', gbest_cost_pso);
fprintf('Computation Time: %.2f seconds\n', pso_time);
fprintf('===========================================================\n');

%% ====================================================
% OPTIMIZATION 2: GENETIC ALGORITHM (GA)
% ====================================================
fprintf('\n================ GA OPTIMIZATION STARTED ================\n');
fprintf('Optimizing pumping/generation schedule using GA...\n');

% GA Parameters
ga_population = 50;
ga_generations = 200;
crossover_rate = 0.8;
mutation_rate = 0.1;
elite_count = 2;
tournament_size = 3;

% Initialize population
population = lb + (ub - lb) .* rand(ga_population, n_vars);
fitness = inf(ga_population, 1);

% GA Optimization Loop
ga_history = zeros(ga_generations, 1);
ga_valid_count = zeros(ga_generations, 1);
ga_avg_fitness = zeros(ga_generations, 1);
ga_time_start = tic;

for gen = 1:ga_generations
    % Evaluate fitness for all individuals
    valid_solutions = 0;
    for i = 1:ga_population
        pump_sched = population(i, 1:24);
        gen_sched = population(i, 25:48);
        
        [cost, valid, ~] = evaluate_psh_schedule_corrected(pump_sched, gen_sched, Load, Period, ...
            Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
            Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);
        
        fitness(i) = cost;
        if valid
            valid_solutions = valid_solutions + 1;
        end
    end
    
    % Track statistics
    [best_fitness, best_idx] = min(fitness);
    ga_history(gen) = best_fitness;
    ga_valid_count(gen) = valid_solutions;
    ga_avg_fitness(gen) = mean(fitness(fitness < 1e9));  % Average of valid solutions
    
    if mod(gen, 40) == 0
        fprintf('GA Generation %d/%d - Best Cost: $%.2f - Valid Solutions: %d/%d\n', ...
            gen, ga_generations, best_fitness, valid_solutions, ga_population);
    end
    
    % Selection, Crossover, and Mutation
    new_population = zeros(ga_population, n_vars);
    
    % Elitism - keep best individuals
    [~, sorted_idx] = sort(fitness);
    for i = 1:elite_count
        new_population(i,:) = population(sorted_idx(i),:);
    end
    
    % Generate offspring
    for i = elite_count+1:ga_population
        % Tournament selection
        parent1 = tournament_selection(population, fitness, tournament_size);
        parent2 = tournament_selection(population, fitness, tournament_size);
        
        % Crossover
        if rand < crossover_rate
            offspring = crossover(parent1, parent2);
        else
            offspring = parent1;
        end
        
        % Mutation
        offspring = mutate(offspring, lb, ub, mutation_rate);
        
        new_population(i,:) = offspring;
    end
    
    population = new_population;
end

ga_time = toc(ga_time_start);

% Extract GA optimal schedule
[gbest_cost_ga, best_idx] = min(fitness);
gbest_ga = population(best_idx,:);
GA_Pumping = gbest_ga(1:24);
GA_Generation = gbest_ga(25:48);

fprintf('\n✅ GA OPTIMIZATION COMPLETED\n');
fprintf('Final Best Cost: $%.2f/day\n', gbest_cost_ga);
fprintf('Computation Time: %.2f seconds\n', ga_time);
fprintf('===========================================================\n');

%% ====================================================
% COMPARATIVE ANALYSIS: PSO vs GA
% ====================================================
fprintf('\n================ PSO vs GA COMPARISON ================\n');
fprintf('Season: %s (%s)\n\n', Current_Season_Name, Current_Season_Desc);

% Evaluate PSO solution
[pso_metrics] = evaluate_detailed_metrics(PSO_Pumping, PSO_Generation, Load, Period, ...
    Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
    Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);

% Evaluate GA solution
[ga_metrics] = evaluate_detailed_metrics(GA_Pumping, GA_Generation, Load, Period, ...
    Max_Pumping_Power, Max_Generation_Power, Pumping_Efficiency, Generation_Efficiency, ...
    Reservoir_Capacity, Initial_SOC, Min_SOC, Max_SOC, Off_Peak_Price, Peak_Price);

% Performance comparison
fprintf('\n--- OPTIMIZATION PERFORMANCE ---\n');
fprintf('                                    PSO              GA\n');
fprintf('----------------------------------------------------------------\n');
fprintf('Final Cost ($/day)              : $%-15.2f $%.2f\n', -gbest_cost_pso, -gbest_cost_ga);
fprintf('Computation Time (sec)          : %-15.2f %.2f\n', pso_time, ga_time);
fprintf('Convergence Speed               : %-15s %s\n', ...
    iif(pso_time < ga_time, 'FASTER ✓', 'Slower'), ...
    iif(ga_time < pso_time, 'FASTER ✓', 'Slower'));

fprintf('\n--- ENERGY METRICS ---\n');
fprintf('Total Pumping (MWh)             : %-15.2f %.2f\n', pso_metrics.pump_total, ga_metrics.pump_total);
fprintf('Total Generation (MWh)          : %-15.2f %.2f\n', pso_metrics.gen_total, ga_metrics.gen_total);
fprintf('Round-Trip Efficiency (%%)       : %-15.2f %.2f\n', pso_metrics.efficiency, ga_metrics.efficiency);
fprintf('Energy Balance Error (MWh)      : %-15.4f %.4f\n', pso_metrics.balance_error, ga_metrics.balance_error);

fprintf('\n--- PEAK MANAGEMENT ---\n');
fprintf('Peak Reduction (MW)             : %-15.2f %.2f\n', pso_metrics.peak_reduction, ga_metrics.peak_reduction);
fprintf('Peak Reduction (%%)              : %-15.2f %.2f\n', pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct);
fprintf('Reduced Peak Load (MW)          : %-15.2f %.2f\n', pso_metrics.reduced_peak, ga_metrics.reduced_peak);
fprintf('Load Variance Reduction (%%)     : %-15.2f %.2f\n', pso_metrics.variance_reduction, ga_metrics.variance_reduction);

fprintf('\n--- ECONOMIC PERFORMANCE ---\n');
fprintf('Daily Pumping Cost ($)          : $%-15.2f $%.2f\n', pso_metrics.pump_cost, ga_metrics.pump_cost);
fprintf('Daily Generation Revenue ($)    : $%-15.2f $%.2f\n', pso_metrics.gen_revenue, ga_metrics.gen_revenue);
fprintf('Daily Net Profit ($)            : $%-15.2f $%.2f\n', pso_metrics.net_profit, ga_metrics.net_profit);

fprintf('\n--- OVERALL WINNER ---\n');
if -gbest_cost_pso > -gbest_cost_ga
    advantage = ((-gbest_cost_pso) - (-gbest_cost_ga)) / (-gbest_cost_ga) * 100;
    fprintf('🏆 PSO PERFORMS BETTER\n');
    fprintf('   Economic advantage: $%.2f/day (%.2f%% better)\n', ...
        (-gbest_cost_pso) - (-gbest_cost_ga), advantage);
    fprintf('   Time advantage: %.2f seconds %s\n', abs(pso_time - ga_time), ...
        iif(pso_time < ga_time, 'faster', 'slower'));
else
    advantage = ((-gbest_cost_ga) - (-gbest_cost_pso)) / (-gbest_cost_pso) * 100;
    fprintf('🏆 GA PERFORMS BETTER\n');
    fprintf('   Economic advantage: $%.2f/day (%.2f%% better)\n', ...
        (-gbest_cost_ga) - (-gbest_cost_pso), advantage);
    fprintf('   Time advantage: %.2f seconds %s\n', abs(ga_time - pso_time), ...
        iif(ga_time < pso_time, 'faster', 'slower'));
end

fprintf('===========================================================\n');

%% ====================================================
% COMPREHENSIVE VISUALIZATION
% ====================================================

%% MASTER COMPARISON PLOT
figure('Color','w','Position',[50 50 1600 900]);
sgtitle(sprintf('PSO vs GA COMPREHENSIVE OPTIMIZATION COMPARISON - %s Season', Current_Season_Name), ...
    'FontSize', 16, 'FontWeight', 'bold');

% 1. Convergence Comparison
subplot(3,3,1);
plot(1:pso_iterations, pso_history, '-', 'LineWidth', 2.5, 'Color', [0.2 0.4 0.8]);
hold on;
plot(1:ga_generations, ga_history, '-', 'LineWidth', 2.5, 'Color', [0.9 0.4 0.2]);
grid on;
xlabel('Iteration/Generation','FontSize',10,'FontWeight','bold');
ylabel('Best Cost ($)','FontSize',10,'FontWeight','bold');
title('Convergence Comparison','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northeast');
xlim([1 max(pso_iterations, ga_generations)]);

% 2. Solution Quality Evolution
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
economic_metrics = [-gbest_cost_pso, -gbest_cost_ga; ...
                    pso_metrics.net_profit, ga_metrics.net_profit];
b = bar(economic_metrics');
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Final Cost', 'Net Profit'});
ylabel('Value ($/day)','FontSize',10,'FontWeight','bold');
title('Economic Performance','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on;

% Add value labels
for i = 1:2
    text(1, economic_metrics(i,1)+50, sprintf('$%.0f', economic_metrics(i,1)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
    text(2, economic_metrics(i,2)+50, sprintf('$%.0f', economic_metrics(i,2)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
end

% 4. Operational Schedules - PSO
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
grid on;
xticks(1:24);

% 5. Operational Schedules - GA
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
grid on;
xticks(1:24);

% 6. Peak Shaving Comparison
subplot(3,3,6);
% Calculate net loads
pso_net_load = Load - PSO_Generation;
ga_net_load = Load - GA_Generation;

plot(hours, Load, '-k', 'LineWidth', 2.5);
hold on;
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

% 7. Energy Metrics Comparison
subplot(3,3,7);
energy_data = [pso_metrics.pump_total, ga_metrics.pump_total; ...
               pso_metrics.gen_total, ga_metrics.gen_total; ...
               pso_metrics.efficiency, ga_metrics.efficiency];
b = bar(energy_data');
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Pumping (MWh)', 'Generation (MWh)', 'Efficiency (%)'});
ylabel('Value','FontSize',10,'FontWeight','bold');
title('Energy Performance','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on;
xtickangle(15);

% 8. Peak Management Metrics
subplot(3,3,8);
peak_data = [pso_metrics.peak_reduction, ga_metrics.peak_reduction; ...
             pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct; ...
             pso_metrics.variance_reduction, ga_metrics.variance_reduction];
b = bar(peak_data');
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.9 0.4 0.2];
set(gca, 'XTickLabel', {'Reduction (MW)', 'Reduction (%)', 'Variance Red (%)'});
ylabel('Value','FontSize',10,'FontWeight','bold');
title('Peak Management Metrics','FontSize',11,'FontWeight','bold');
legend('PSO', 'GA', 'Location', 'northwest');
grid on;
xtickangle(15);

% 9. Overall Winner Display with Seasonal Context
subplot(3,3,9);
axis off;

% Determine winner
if -gbest_cost_pso > -gbest_cost_ga
    winner = 'PSO';
    winner_color = [0.2 0.4 0.8];
    advantage_pct = ((-gbest_cost_pso) - (-gbest_cost_ga)) / (-gbest_cost_ga) * 100;
    time_diff = pso_time - ga_time;
else
    winner = 'GA';
    winner_color = [0.9 0.4 0.2];
    advantage_pct = ((-gbest_cost_ga) - (-gbest_cost_pso)) / (-gbest_cost_pso) * 100;
    time_diff = ga_time - pso_time;
end

% Trophy and winner announcement
text(0.5, 0.90, '🏆', 'FontSize', 50, 'HorizontalAlignment', 'center');
text(0.5, 0.75, sprintf('%s WINS!', winner), 'FontSize', 18, 'FontWeight', 'bold', ...
     'HorizontalAlignment', 'center', 'Color', winner_color);

text(0.5, 0.62, sprintf('Season: %s', Current_Season_Name), ...
     'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
     'Color', [0.3 0.3 0.3]);

text(0.5, 0.52, sprintf('Economic Advantage: %.2f%%', advantage_pct), ...
     'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

text(0.5, 0.43, sprintf('Cost: $%.2f vs $%.2f/day', -gbest_cost_pso, -gbest_cost_ga), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');

text(0.5, 0.35, sprintf('Time: %.2f vs %.2f sec', pso_time, ga_time), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');

text(0.5, 0.27, sprintf('Peak Reduction: %.1f%% vs %.1f%%', ...
     pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');

text(0.5, 0.19, sprintf('Efficiency: %.2f%% vs %.2f%%', ...
     pso_metrics.efficiency, ga_metrics.efficiency), ...
     'FontSize', 10, 'HorizontalAlignment', 'center');

text(0.5, 0.10, sprintf('Load Factor: %.2fx Base', Current_Season_Factor), ...
     'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

xlim([0 1]);
ylim([0 1]);

%% SEASONAL COMPARISON FIGURE
figure('Color','w','Position',[100 100 1400 700]);
sgtitle('SEASONAL IMPACT ON PSH OPERATIONS - EGYPT', 'FontSize', 16, 'FontWeight', 'bold');

% Calculate loads for all seasons
seasonal_loads = zeros(4, 24);
for s = 1:4
    seasonal_loads(s,:) = Base_Load * Season_Factors(s);
end

% Plot 1: Seasonal Load Profiles
subplot(2,3,1);
colors = [0.9 0.2 0.2; 0.9 0.6 0.2; 0.2 0.6 0.9; 0.4 0.8 0.4];
for s = 1:4
    plot(hours, seasonal_loads(s,:), '-', 'LineWidth', 2, 'Color', colors(s,:), ...
         'DisplayName', Season_Names(s));
    hold on;
end
grid on;
xlabel('Hour','FontSize',10,'FontWeight','bold');
ylabel('Load (MW)','FontSize',10,'FontWeight','bold');
title('Seasonal Load Profiles','FontSize',11,'FontWeight','bold');
legend('Location', 'northwest');

% Plot 2: Seasonal Peak Comparison
subplot(2,3,2);
seasonal_peaks = max(seasonal_loads, [], 2);
b = bar(seasonal_peaks, 'FaceColor', 'flat');
for s = 1:4
    b.CData(s,:) = colors(s,:);
end
set(gca, 'XTickLabel', Season_Names);
ylabel('Peak Load (MW)','FontSize',10,'FontWeight','bold');
title('Seasonal Peak Demands','FontSize',11,'FontWeight','bold');
grid on;
for s = 1:4
    text(s, seasonal_peaks(s)+500, sprintf('%.0f MW', seasonal_peaks(s)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

% Plot 3: Seasonal Load Factors
subplot(2,3,3);
b = bar(Season_Factors, 'FaceColor', 'flat');
for s = 1:4
    b.CData(s,:) = colors(s,:);
end
set(gca, 'XTickLabel', Season_Names);
ylabel('Load Multiplier','FontSize',10,'FontWeight','bold');
title('Seasonal Load Factors','FontSize',11,'FontWeight','bold');
yline(1, '--k', 'Base Load', 'LineWidth', 1.5);
grid on;
for s = 1:4
    text(s, Season_Factors(s)+0.05, sprintf('%.2fx', Season_Factors(s)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

% Plot 4: Monthly Temperature Profile (Egypt)
subplot(2,3,4);
months = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
avg_temps = [18, 19, 22, 26, 30, 33, 35, 35, 32, 28, 23, 19];  % Egypt average temps (°C)
plot(1:12, avg_temps, '-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0.9 0.3 0.2]);
hold on;
% Highlight seasons
patch([1 2 2 1], [0 0 40 40], colors(3,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
patch([3 5 5 3], [0 0 40 40], colors(4,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
patch([6 8 8 6], [0 0 40 40], colors(1,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
patch([9 11 11 9], [0 0 40 40], colors(2,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
patch([12 12 12 12], [0 0 40 40], colors(3,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
grid on;
xlabel('Month','FontSize',10,'FontWeight','bold');
ylabel('Temperature (°C)','FontSize',10,'FontWeight','bold');
title('Egypt Monthly Temperature Profile','FontSize',11,'FontWeight','bold');
set(gca, 'XTick', 1:12, 'XTickLabel', months);
xtickangle(45);
ylim([0 40]);

% Plot 5: PSH Utilization by Season
subplot(2,3,5);
% Estimate PSH utilization based on load factors
psh_utilization = [95, 70, 45, 65];  % Estimated % utilization
b = bar(psh_utilization, 'FaceColor', 'flat');
for s = 1:4
    b.CData(s,:) = colors(s,:);
end
set(gca, 'XTickLabel', Season_Names);
ylabel('PSH Utilization (%)','FontSize',10,'FontWeight','bold');
title('Expected PSH Capacity Utilization','FontSize',11,'FontWeight','bold');
grid on;
ylim([0 100]);
for s = 1:4
    text(s, psh_utilization(s)+3, sprintf('%.0f%%', psh_utilization(s)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

% Plot 6: Seasonal Recommendations
subplot(2,3,6);
axis off;
text(0.5, 0.95, 'SEASONAL OPERATING RECOMMENDATIONS', 'FontSize', 12, 'FontWeight', 'bold', ...
     'HorizontalAlignment', 'center');

y_pos = 0.80;
line_height = 0.18;

% Summer
text(0.05, y_pos, '☀️ SUMMER (Jun-Aug)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', colors(1,:));
text(0.08, y_pos-0.05, '• Maximum PSH deployment', 'FontSize', 9);
text(0.08, y_pos-0.09, '• Critical for grid stability', 'FontSize', 9);
text(0.08, y_pos-0.13, '• Highest revenue potential', 'FontSize', 9);

% Autumn
y_pos = y_pos - line_height;
text(0.05, y_pos, '🍂 AUTUMN (Sep-Nov)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', colors(2,:));
text(0.08, y_pos-0.05, '• Moderate PSH operations', 'FontSize', 9);
text(0.08, y_pos-0.09, '• Standard peak shaving', 'FontSize', 9);

% Winter
y_pos = y_pos - line_height;
text(0.05, y_pos, '❄️ WINTER (Dec-Feb)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', colors(3,:));
text(0.08, y_pos-0.05, '• Reduced PSH demand', 'FontSize', 9);
text(0.08, y_pos-0.09, '• Ideal for maintenance', 'FontSize', 9);

% Spring
y_pos = y_pos - line_height;
text(0.05, y_pos, '🌸 SPRING (Mar-May)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', colors(4,:));
text(0.08, y_pos-0.05, '• Increasing PSH utilization', 'FontSize', 9);
text(0.08, y_pos-0.09, '• Prepare for summer peaks', 'FontSize', 9);

xlim([0 1]);
ylim([0 1]);

%% Save comparison results
fprintf('\n================ SAVING COMPARISON RESULTS ================\n');

T_Comparison = table(...
    {'Final Cost ($/day)'; 'Computation Time (sec)'; 'Total Pumping (MWh)'; ...
     'Total Generation (MWh)'; 'Round-Trip Efficiency (%)'; 'Peak Reduction (MW)'; ...
     'Peak Reduction (%)'; 'Variance Reduction (%)'; 'Daily Net Profit ($)'; ...
     'Energy Balance Error (MWh)'}, ...
    [-gbest_cost_pso; pso_time; pso_metrics.pump_total; pso_metrics.gen_total; ...
     pso_metrics.efficiency; pso_metrics.peak_reduction; pso_metrics.peak_reduction_pct; ...
     pso_metrics.variance_reduction; pso_metrics.net_profit; pso_metrics.balance_error], ...
    [-gbest_cost_ga; ga_time; ga_metrics.pump_total; ga_metrics.gen_total; ...
     ga_metrics.efficiency; ga_metrics.peak_reduction; ga_metrics.peak_reduction_pct; ...
     ga_metrics.variance_reduction; ga_metrics.net_profit; ga_metrics.balance_error], ...
    'VariableNames', {'Metric', 'PSO', 'GA'});

% Add seasonal information
T_Seasonal = table(...
    Season_Names', Season_Factors', seasonal_peaks, psh_utilization', ...
    'VariableNames', {'Season', 'Load_Factor', 'Peak_Load_MW', 'PSH_Utilization_Percent'});

filename = sprintf('Egypt_PSH_PSO_vs_GA_Comparison_%s_Season.xlsx', Current_Season_Name);
writetable(T_Comparison, filename, 'Sheet', 'Comparison_Summary');
writetable(T_Seasonal, filename, 'Sheet', 'Seasonal_Analysis');

fprintf('✅ Comparison results saved to: %s\n', filename);
fprintf('   - Sheet 1: Comparison_Summary\n');
fprintf('   - Sheet 2: Seasonal_Analysis\n');
fprintf('===========================================================\n\n');

fprintf('====================================================\n');
fprintf(' OPTIMIZATION COMPARISON COMPLETED SUCCESSFULLY\n');
fprintf(' Season: %s (%s)\n', Current_Season_Name, Current_Season_Desc);
fprintf('====================================================\n');

%% ====================================================
% SUPPORTING FUNCTIONS
% ====================================================

function [cost, valid, metrics] = evaluate_psh_schedule_corrected(pump, gen, Load, Period, ...
    Max_Pump, Max_Gen, Pump_Eff, Gen_Eff, Res_Cap, Init_SOC, Min_SOC, Max_SOC, ...
    Off_Peak_Price, Peak_Price)
    
    reservoir = Res_Cap * Init_SOC;
    valid = true;
    
    total_pump_cost = 0;
    total_gen_revenue = 0;
    peak_demand_reduction = 0;
    
    pump_energy_total = 0;
    gen_energy_total = 0;
    pump_hydraulic_total = 0;
    gen_hydraulic_total = 0;
    
    for h = 1:24
        if Period(h) == "OFF-PEAK"
            gen(h) = 0;
        else
            pump(h) = 0;
        end
        
        if pump(h) > 0
            available_space = (Res_Cap * Max_SOC) - reservoir;
            max_pump_possible = available_space / Pump_Eff;
            
            actual_pump = min([pump(h), Max_Pump, max_pump_possible]);
            actual_pump = max(0, actual_pump);
            
            energy_stored = actual_pump * Pump_Eff;
            reservoir = reservoir + energy_stored;
            
            total_pump_cost = total_pump_cost + actual_pump * Off_Peak_Price;
            pump_energy_total = pump_energy_total + actual_pump;
            pump_hydraulic_total = pump_hydraulic_total + energy_stored;
        end
        
        if gen(h) > 0
            available_energy = reservoir - (Res_Cap * Min_SOC);
            max_gen_hydraulic = available_energy;
            max_gen_electrical = max_gen_hydraulic * Gen_Eff;
            
            actual_gen = min([gen(h), Max_Gen, max_gen_electrical]);
            actual_gen = max(0, actual_gen);
            
            energy_released = actual_gen / Gen_Eff;
            reservoir = reservoir - energy_released;
            
            total_gen_revenue = total_gen_revenue + actual_gen * Peak_Price;
            gen_energy_total = gen_energy_total + actual_gen;
            gen_hydraulic_total = gen_hydraulic_total + energy_released;
            
            net_load = Load(h) - actual_gen;
            original_peak_contribution = Load(h);
            peak_demand_reduction = peak_demand_reduction + (original_peak_contribution - net_load);
        end
        
        if reservoir < Res_Cap * Min_SOC - 0.1 || reservoir > Res_Cap * Max_SOC + 0.1
            valid = false;
        end
    end
    
    if gen_hydraulic_total > pump_hydraulic_total * 1.01
        valid = false;
    end
    
    if pump_energy_total > 0
        actual_efficiency = (gen_energy_total / pump_energy_total);
        theoretical_max = Pump_Eff * Gen_Eff * 1.01;
        if actual_efficiency > theoretical_max
            valid = false;
        end
    end
    
    peak_benefit_value = peak_demand_reduction * 10;
    cost = -(total_gen_revenue - total_pump_cost + peak_benefit_value);
    
    if ~valid
        cost = cost + 1e9;
    end
    
    metrics.pump_total = pump_energy_total;
    metrics.gen_total = gen_energy_total;
    metrics.peak_reduction = peak_demand_reduction;
    metrics.efficiency = gen_energy_total / max(pump_energy_total, 0.001) * 100;
end

function [metrics] = evaluate_detailed_metrics(pump, gen, Load, Period, ...
    Max_Pump, Max_Gen, Pump_Eff, Gen_Eff, Res_Cap, Init_SOC, Min_SOC, Max_SOC, ...
    Off_Peak_Price, Peak_Price)
    
    reservoir = Res_Cap * Init_SOC;
    
    total_pump_cost = 0;
    total_gen_revenue = 0;
    
    pump_energy_total = 0;
    gen_energy_total = 0;
    pump_hydraulic_total = 0;
    gen_hydraulic_total = 0;
    
    net_load = zeros(1, 24);
    
    for h = 1:24
        if Period(h) == "OFF-PEAK"
            gen(h) = 0;
        else
            pump(h) = 0;
        end
        
        if pump(h) > 0
            available_space = (Res_Cap * Max_SOC) - reservoir;
            max_pump_possible = available_space / Pump_Eff;
            
            actual_pump = min([pump(h), Max_Pump, max_pump_possible]);
            actual_pump = max(0, actual_pump);
            
            energy_stored = actual_pump * Pump_Eff;
            reservoir = reservoir + energy_stored;
            
            total_pump_cost = total_pump_cost + actual_pump * Off_Peak_Price;
            pump_energy_total = pump_energy_total + actual_pump;
            pump_hydraulic_total = pump_hydraulic_total + energy_stored;
        end
        
        if gen(h) > 0
            available_energy = reservoir - (Res_Cap * Min_SOC);
            max_gen_hydraulic = available_energy;
            max_gen_electrical = max_gen_hydraulic * Gen_Eff;
            
            actual_gen = min([gen(h), Max_Gen, max_gen_electrical]);
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
    
    % Calculate metrics
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
    tournament_fitness = fitness(tournament_idx);
    [~, winner_idx] = min(tournament_fitness);
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
    if condition
        result = true_val;
    else
        result = false_val;
    end
end