### MGUS to symMM
est =  0.08744776
se = sqrt(4.00957E-05)

lb = est^(exp(-1.96*se/(est*log(est))))
ub = est^(exp(1.96*se/(est*log(est))))
round(est*100,1)
round(lb*100,1); round(ub*100,1)


### smolMM to symMMd
est =  0.4762066
se = sqrt(8.82609E-05)

lb = est^(exp(-1.96*se/(est*log(est))))
ub = est^(exp(1.96*se/(est*log(est))))
round(est*100,1)
round(lb*100,1); round(ub*100,1)
