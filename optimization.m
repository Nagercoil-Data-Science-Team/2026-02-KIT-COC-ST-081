clc;
clear;
close all;

fprintf('====================================================\n');
fprintf(' EGYPT PSH SYSTEM - PSO vs GA OPTIMIZATION COMPARISON\n');
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
sgtitle('PSO vs GA COMPREHENSIVE OPTIMIZATION COMPARISON', ...
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

% 9. Overall Winner Display
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
text(0.5, 0.85, '🏆', 'FontSize', 60, 'HorizontalAlignment', 'center');
text(0.5, 0.65, sprintf('%s WINS!', winner), 'FontSize', 20, 'FontWeight', 'bold', ...
     'HorizontalAlignment', 'center', 'Color', winner_color);

text(0.5, 0.50, sprintf('Economic Advantage: %.2f%%', advantage_pct), ...
     'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

text(0.5, 0.40, sprintf('Cost: $%.2f vs $%.2f/day', -gbest_cost_pso, -gbest_cost_ga), ...
     'FontSize', 11, 'HorizontalAlignment', 'center');

text(0.5, 0.30, sprintf('Time: %.2f vs %.2f sec', pso_time, ga_time), ...
     'FontSize', 11, 'HorizontalAlignment', 'center');

text(0.5, 0.20, sprintf('Peak Reduction: %.1f%% vs %.1f%%', ...
     pso_metrics.peak_reduction_pct, ga_metrics.peak_reduction_pct), ...
     'FontSize', 11, 'HorizontalAlignment', 'center');

text(0.5, 0.10, sprintf('Efficiency: %.2f%% vs %.2f%%', ...
     pso_metrics.efficiency, ga_metrics.efficiency), ...
     'FontSize', 11, 'HorizontalAlignment', 'center');

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

filename = 'Egypt_PSH_PSO_vs_GA_Comparison.xlsx';
writetable(T_Comparison, filename, 'Sheet', 'Comparison_Summary');

fprintf('✅ Comparison results saved to: %s\n', filename);
fprintf('===========================================================\n\n');

fprintf('====================================================\n');
fprintf(' OPTIMIZATION COMPARISON COMPLETED SUCCESSFULLY\n');
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