# fs_outlier_with_BBG
Detect financial statement outliers from database and compare them with Bloomberg 

Step1: Use 3 methods to identify possible outliers in our system: using exponential distribution; by relative change; by TZ-score and Local Outlier Factor(LOF).
Step2: Use Bloomberg API to verify if those suspicious outliers are truly different from bbg terminal.
