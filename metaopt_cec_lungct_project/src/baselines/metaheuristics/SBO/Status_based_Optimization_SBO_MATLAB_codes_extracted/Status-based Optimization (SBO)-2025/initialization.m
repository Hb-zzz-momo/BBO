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

% This function initialize the first population of search agents
function Positions=initialization(SearchAgents_no,dim,ub,lb)

Boundary_no= size(ub,2); % numnber of boundaries

% If the boundaries of all variables are equal and user enter a signle
% number for both ub and lb
if Boundary_no==1
    Positions=rand(SearchAgents_no,dim).*(ub-lb)+lb;
end

% If each variable has a different lb and ub
if Boundary_no>1
    for i=1:dim
        ub_i=ub(i);
        lb_i=lb(i);
        Positions(:,i)=rand(SearchAgents_no,1).*(ub_i-lb_i)+lb_i;
    end
end