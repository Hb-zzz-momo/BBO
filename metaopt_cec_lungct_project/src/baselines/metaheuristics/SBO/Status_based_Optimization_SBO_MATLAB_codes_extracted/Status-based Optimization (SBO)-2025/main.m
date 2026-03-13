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

% Single run
close all;clear;clc;

N=30; % population
F='F1'; % Function F1 to F23  
T=500; % maximum number of iterations 

[lb,ub,D,fobj]=Get_Functions_details(F); % Load function detailsSBO

[sBest,pBest,Conv]=SBO(N,T,lb,ub,D,fobj);  % function call

% Plot search space
figure('Position',[454   445   694   297]);
subplot(1,2,1);
func_plot(F);
title([F,' Parameter space'])
xlabel('x_1');
ylabel('x_2');
zlabel([F,'( x_1 , x_2 )'])

% Plot convergence curve
subplot(1,2,2);
semilogy(Conv,'-r','LineWidth',2)
title([F,' Convergence curve'])
xlabel('Iteration#');
ylabel('Best fitness function');
axis tight
legend('SBO')

% Optimal result output
display(['The best solution obtained by ESC is : ', num2str(pBest)]);
display(['The best optimal values of the objective funciton found by SBO is : ', num2str(sBest)]);