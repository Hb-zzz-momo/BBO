% 📜 Status-based Optimization (SBO) source codes (version 1.0)
% 🌐 Website and codes of SBO:  The Status-based Optimization: Algorithm and comprehensive performance analysis:
 
% 🔗 https://aliasgharheidari.com/SBO.html

% 👥 Jian Wang, Yi Chen, Ali Asghar Heidari, Zongda Wu, Huiling Chen

% 📅 Last update: 06 10 2025

% 📧 E-Mail: jona.wzu@gmail.com, aliasghar68@gmail.com, chenhuiling.jlu@gmail.com
  
% 📜 After use of code, please users cite the main paper on SBO: 
% The Status-based Optimization: Algorithm and comprehensive performance analysis
% Jian Wang, Yi Chen, Ali Asghar Heidari, Zongda Wu, Huiling Chen
% Neurocomputing, 2025

%----------------------------------------------------------------------------------------------------------------------------------------------------%
% 📊 You can use and compare with other optimization methods developed recently:
%     - (SBO) 2025: 🔗 https://aliasgharheidari.com/SBO.html
%     - (ESC) 2024: 🔗 https://aliasgharheidari.com/ESC.html
%     - (MGO) 2024: 🔗 https://aliasgharheidari.com/MGO.html
%     - (PLO) 2024: 🔗 https://aliasgharheidari.com/PLO.html
%     - (FATA) 2024: 🔗 https://aliasgharheidari.com/FATA.html
%     - (ECO) 2024: 🔗 https://aliasgharheidari.com/ECO.html
%     - (AO) 2024: 🔗 https://aliasgharheidari.com/AO.html
%     - (PO) 2024: 🔗 https://aliasgharheidari.com/PO.html
%     - (RIME) 2023: 🔗 https://aliasgharheidari.com/RIME.html
%     - (INFO) 2022: 🔗 https://aliasgharheidari.com/INFO.html
%     - (RUN) 2021: 🔗 https://aliasgharheidari.com/RUN.html
%     - (HGS) 2021: 🔗 https://aliasgharheidari.com/HGS.html
%     - (SMA) 2020: 🔗 https://aliasgharheidari.com/SMA.html
%     - (HHO) 2019: 🔗 https://aliasgharheidari.com/HHO.html
%----------------------------------------------------------------------------------------------------------------------------------------------------%

function [bestFitness, best_pos, Convergence_curve] = SBO(N, MaxFEs, lb, ub, dim, fobj)
    
    %% INITIALIZATION
    FEs = 0;
    bestFitness = inf; % Change to -inf for maximization problems
    best_pos = zeros(1, dim);
    
    Convergence_curve = [];
    iter = 1;

    % Initialize populations
    current_X = initialization(N, dim, ub, lb);
    localElite_X = initialization(N, dim, ub, lb);
        
    % Initialize fitness values
    current_Fitness = inf * ones(N, 1);
    localElite_Fitness = inf * ones(N, 1);
    
    % Calculate initial fitness and determine initial best solutions (local and global)
    for i = 1:N
        current_Fitness(i, 1) = fobj(current_X(i, :));
        FEs = FEs + 1;
        
        temp_localElite_Fitness = fobj(localElite_X(i ,:));
        FEs = FEs + 1;
        
        % Determine the initial local elite
        if current_Fitness(i, 1) < temp_localElite_Fitness
            localElite_X(i, :) = current_X(i, :);
            localElite_Fitness(i, 1) = current_Fitness(i, 1);
        else
            localElite_Fitness(i, 1) = temp_localElite_Fitness;
        end
        
        % Update the initial global best
        if localElite_Fitness(i, 1) < bestFitness
            bestFitness = localElite_Fitness(i, 1);
            best_pos = localElite_X(i, :);
        end
    end
    
    %% Sort the local elite fitness for the first Roulette Wheel Selection
    [sorted_localElite_Fitness, ~] = sort(localElite_Fitness);
    
    %% Social success flag and social fitness initialization
    flag = ones(N, 1);
    social_Fitness = inf * ones(N, 1);
    
    %% MAIN LOOP
    while FEs < MaxFEs
        
        %% Select an individual from the localElite population based on Roulette selection
        Roulette_index = RouletteWheelSelection(1./(sorted_localElite_Fitness + eps));
        if Roulette_index == -1  
            Roulette_index = 1; % Default to the best if selection fails
        end
        
        %% Update the current population
        for i = 1:N
            w1 = randn;
            w2 = randn;
            w3 = tanh((sqrt(abs(MaxFEs - randn * FEs))/i)^(FEs/MaxFEs));
            w4 = unifrnd(-w3, w3);
            if rand < w3
                for j = 1:dim
                    current_X(i, j) = (1 - w1 - w2) * current_X(i, j) + w1 * localElite_X(Roulette_index, j) + w2 * best_pos(j);
                end
            else
                for j = 1:dim
                    current_X(i, j) = w4 * ((1 - w1 - w2) * current_X(i, j) + w1 * localElite_X(Roulette_index, j) + w2 * best_pos(j));
                end
            end
        end
        
        %% Boundary control
        current_X = BoundaryControl(current_X, lb, ub);
        
        %% Upward social strategy
        social_X = current_X;
        
        % One-dimension source exchange for socially successful individuals
        for i = 1:N
            if flag(i) == 1
                social_X1_val = localElite_X(i, randi(dim));
                social_X2_val = best_pos(randi(dim));
                social_X(i, randi(dim)) = (social_X1_val + social_X2_val) / 2;
            end
        end
        
        % Multi-dimension source exchange for socially failed individuals
        m = zeros(1, dim);
        u = randperm(dim);
        m(u(1:ceil(rand * dim))) = 1;
        for i = 1:N
            if flag(i) == 0
                for j = 1:dim
                    if m(j)
                        social_X(i, j) = localElite_X(i, j);
                    end
                end
            end
        end
        
        %% Greedy selection and current population update
        for i = 1:N
            % Evaluate new and social positions
            if FEs < MaxFEs
                current_Fitness(i, 1) = fobj(current_X(i, :));
                FEs = FEs + 1;
            end
            if FEs < MaxFEs
                social_Fitness(i, 1) = fobj(social_X(i, :));
                FEs = FEs + 1;
            end
            
            % Greedy selection
            if social_Fitness(i, 1) < current_Fitness(i, 1)
                % Social success: update position and set flag
                flag(i, 1) = 1;
                current_X(i, :) = social_X(i, :);
                current_Fitness(i, 1) = social_Fitness(i, 1);
            else
                % Social fail: keep current position and set flag
                flag(i, 1) = 0;
            end
        end
        
        %% Update local elite population
        for i = 1:N
            if current_Fitness(i, 1) < localElite_Fitness(i, 1)
                localElite_Fitness(i, 1) = current_Fitness(i, 1);
                localElite_X(i, :) = current_X(i, :);
            end
        end
        
        %% Sort local elite fitness and update the global best position
        [sorted_localElite_Fitness, idx] = sort(localElite_Fitness);
        if sorted_localElite_Fitness(1) < bestFitness
            bestFitness = sorted_localElite_Fitness(1);
            best_pos = localElite_X(idx(1), :);
        end
    
        %% Record the best fitness for the convergence curve
        Convergence_curve(iter) = bestFitness;
        iter = iter + 1;
    end
end  

%% Helper Functions

% Enforce boundary constraints on agent positions
function X = BoundaryControl(X, low, up)
    [N, dim] = size(X);
    
    if isscalar(low)
        low = repmat(low, 1, dim);
    end
    if isscalar(up)
        up = repmat(up, 1, dim);
    end
    
    for i = 1:N
        for j = 1:dim                
            k = rand < rand; % 50% chance for either clipping or re-initializing
            
            if X(i,j) < low(j) 
                if k
                    X(i,j) = low(j); % Clipping to the boundary
                else
                    X(i,j) = rand * (up(j) - low(j)) + low(j); % Re-initializing
                end 
            end        
            
            if X(i,j) > up(j)  
                if k
                    X(i,j) = up(j); % Clipping to the boundary
                else
                    X(i,j) = rand * (up(j) - low(j)) + low(j); % Re-initializing
                end 
            end
        end
    end
end
    
% Roulette wheel selection mechanism
function choice = RouletteWheelSelection(weights)
    % Normalize weights to handle negative values if any, although 1/fitness should be positive
    if any(weights<0)
        weights = weights + min(weights);
    end
    accumulation = cumsum(weights);
    if accumulation(end) == 0
        choice = -1;
        return;
    end
    p = rand() * accumulation(end);
    chosen_index = -1;
    for index = 1:length(accumulation)
        if (accumulation(index) > p)
            chosen_index = index;
            break;
        end
    end
    choice = chosen_index;
end