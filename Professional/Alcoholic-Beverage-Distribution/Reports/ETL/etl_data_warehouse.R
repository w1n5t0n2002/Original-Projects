library(dplyr)
library(RODBC)
source('C:/Users/pmwash/Desktop/R_files/Data Input/Helper.R')







# TESTING STAGING DATABASE

#unsaleable monthly report data
staging_db = 'N:/Operations Intelligence/Data/STaging/Staging-Database.accdb'
odbc_staging = odbcConnectAccess2007(staging_db)
UNSALEABLE_REPORT_RAW_DATA = sqlQuery(odbc_staging, "SELECT [#MIVDT],[#MINP#], [#MTRCD], [#MIVDT], [#MCUS#], [#MQTYS], [#MCOS$], [#MQPC], [#MCMP], [#MQTY@], [#MCMRC], [#MBRND], [#MCLA@], [#MSUPL]
          FROM WSFILE002_MTC1CI
          WHERE (((WSFILE002_MTC1CI.[#MTRCD])='A') 
          AND ((WSFILE002_MTC1CI.[#MIVDT])>1160601 And (WSFILE002_MTC1CI.[#MIVDT])<1160614) 
          AND ((WSFILE002_MTC1CI.[#MCMRC])=2));
         ")
tail(UNSALEABLE_REPORT_RAW_DATA)



UNSALEABLE_EXTRACT = sqlQuery(odbc_staging, "SELECT WSFILE002_RCT1.[#RDATE], WSFILE002_RCT1.[#RPRD#], WSFILE002_RCT1.[#RDESC], WSFILE002_PRD1.[PBRAN#], WSFILE002_RCT1.[#RCASE], WSFILE002_RCT1.[#RBOTT], WSFILE002_RCT1.[#RQPC], WSFILE002_RCT1.[#RFOB], WSFILE002_DIRDIV.DDUSERN, WSFILE002_SUP1.[#SSUP#], WSFILE002_SUP1.[#SSUNM]
FROM WSFILE002_DIRDIV INNER JOIN (WSFILE002_RCT1 INNER JOIN (WSFILE002_PRD1 INNER JOIN WSFILE002_SUP1 ON WSFILE002_PRD1.PSUPPL = WSFILE002_SUP1.[#SSUP#]) ON WSFILE002_RCT1.[#RPRD#] = WSFILE002_PRD1.[PPROD#]) ON WSFILE002_DIRDIV.DDSUPP = WSFILE002_SUP1.[#SSUP#]
                                      WHERE (((WSFILE002_RCT1.[#RDATE])>1160601 And (WSFILE002_RCT1.[#RDATE])<1160608) AND ((WSFILE002_RCT1.[#RTRC@])='A') AND ((WSFILE002_RCT1.[#RCODE])=2));
                                      ")
tail(UNSALEABLE_EXTRACT)

         # WHERE #RDATE BETWEEN "#1160601#" AND "#1160608#"')
# WHERE #RCOMP <> 0
         # AND #RTRC@ <> '0' 
         # AND #RDATE BETWEEN 1160601 AND 1160608
         # AND #rcode < 8 
         # AND EXT_COST <> 0
         # AND #RTRC@ == 'A'")
sqlQuery(odbc_staging, 'SELECT column_name,* FROM WSFILE002_MTC1.columns')





print('This is a time series summary of Production',
      'no other way unless we want to store a fuck ton of data')
# first run VBA to collect data, then R script to do it up right


etl_production = function(stl, kc) {
  library(timeDate)
  
  k = kc
  s = stl
  colnames(k) = paste0('KC.', colnames(k))
  colnames(s) = paste0('STL.', colnames(s))
  colnames(k)[1] = 'DATE'
  colnames(s)[1] = 'DATE'
  k$KC.YEAR = NA
  k$KC.MONTH = NA
  
  k$DATE = as.character(strptime(k$DATE, '%m/%d/%Y'))
  s$DATE = as.character(strptime(s$DATE, '%m/%d/%Y'))
  
  state = merge(s, k, by='DATE', all=TRUE)
  colnames(state) = ifelse(grepl('YEAR', colnames(state)), 'YEAR', 
                           ifelse(grepl('SEASON', colnames(state)), 'SEASON',
                                  ifelse(grepl('MONTH', colnames(state)), 'MONTH', colnames(state))))
  
  state = state[, colSums(is.na(state)) < nrow(state)]
  names(state) = gsub("\\.", "", names(state))
  
  dat = state$DATE
  state$MONTH = month(dat, TRUE, FALSE)
  month = month(dat)
  state$YEAR = year(dat)
  state$SEASON = ifelse(month==1 | month==2 |month==3, "Winter", 
                              ifelse(month==4 | month==5 | month==6, "Spring",
                                     ifelse(month==7 | month==8 | month==9, "Summer",
                                            ifelse(month==10 | month==11 | month==12, "Fall", ""))))
  state$WEEKDAY = wday(dat, TRUE, FALSE)
  state$DOTM = dom = mday(dat)
  dom = as.numeric(dom)
  state$DOTY = yday(dat)
  state$WEEKNUM = week(dat)
  fd = NULL
  
  for(i in 1:length(dom)) {
    j = i - 1
    if(i == 1) {
      fd[i] = 'YES'
    } else if (dom[i] > dom[j]) {
      fd[i] = 'NO'
    } else {
      fd[i] = 'YES'
    }
    fd
  }
  state$FIRSTDAYOFMONTH = fd
  
  ld = NULL
  
  for(i in 1:length(dom)) {
    j = i + 1
    
    if(i == 1) {
      ld[i] = 'NO'
    } else if (j > length(dom)) {
      ld[i] = 'YES'
    } else if (dom[i] > dom[j]) {
      ld[i] = 'YES'
    } else if (dom[i] < 20) {
      ld[i] = 'NO'
    } else {
      ld[i] = 'NO'
    }
    ld
  }
  state$LASTDAYOFMONTH = ld
  #head(state[, c('DATE', 'LASTDAYOFMONTH')], 70)
  print(state)
  
}


path_stl = 'N:/Operations Intelligence/Monthly Reports/Production/Production History/STL Production Report Daily Data Archive.csv'
path_kc = 'M:/Operations Intelligence/Monthly Reports/Production/Production History/KC Production Report Daily Data Archive.csv'
stl = read.csv(path_stl, header=TRUE)
kc = read.csv(path_kc, header=TRUE)

production = etl_production(stl=stl, kc=kc)
headTail(production)

write.csv(production, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/production_ts_upload.csv', na='', row.names=FALSE)



















print('prepare unsaleables for upload to warehouse')

# pw_returns

etl_returns = function(returns) {
  library(lubridate) 
  
  names(returns) = c('Date', 'Product', 'Customer', 'Supplier', 'Cases', 'Cost', 'Warehouse')
  
  returns$Cases = round(-1 * returns$Cases, 2)
  returns$Cost = round(-1 * returns$Cost, 2)
  
  returns$Date = as400Date(returns$Date)
  returns$Month = month(returns$Date, label=TRUE, abbr=FALSE)
  returns$Year = year(returns$Date)
  
  w = returns$Warehouse
  returns$Warehouse = ifelse(w==1, 'KC', 
                             ifelse(w==2, 'STL', 
                                    ifelse(w==3, 'COL', 
                                           ifelse(w==4, 'CAPE', 'SPFD'))))
  
  returns
}

returns = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_returns.csv', header=TRUE)

returns = etl_returns(returns)
headTail(returns)

write.csv(returns, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/returns_upload.csv')
















# pw_unsell

etl_unsaleables = function(rct) {
  library(lubridate)
  source('C:/Users/pmwash/Desktop/R_files/Data Input/Helper.R')
  
  names(rct) = c('Date', 'Product.ID', 'Product', 'Cases', 'Cost', 'Supplier.ID', 'Supplier', 'Class', 'Warehouse')
  
  rct$Date = as400Date(rct$Date)
  rct$Month = month(rct$Date, label=TRUE, abbr=FALSE)
  rct$Year = year(rct$Date)
  
  rct$Cases = round(-1 * rct$Cases, 2)
  rct$Cost = round(-1 * rct$Cost, 2)
  
  rct$Warehouse = ifelse(rct$Warehouse == 2, 'STL', 'KC')
  
  class = rct$Class
  rct$Class = ifelse(class==10, 'Liquor & Spirits', 
                     ifelse(class==25, 'Liquor & Spirits',
                            ifelse(class==50, 'Wine', 
                                   ifelse(class==51, 'Wine', 
                                          ifelse(class==53, 'Wine', 
                                                 ifelse(class==55, 'Wine', 
                                                        ifelse(class==58, 'Beer & Cider', 
                                                               ifelse(class==59, 'Beer & Cider', 
                                                                      ifelse(class==70, 'Wine', 
                                                                             ifelse(class==80, 'Beer & Cider', 
                                                                                    ifelse(class==84, 'Beer & Cider', 
                                                                                           ifelse(class==85, 'Beer & Cider', 
                                                                                                  ifelse(class==86, 'Beer & Cider', 
                                                                                                         ifelse(class==87, 'Beer & Cider',
                                                                                                                ifelse(class==88, 'Beer & Cider', 
                                                                                                                       ifelse(class>=90, 'Non-Alcoholic', 'NOT SPECIFIED'))))))))))))))))
  
  
  rct = arrange(rct, Date)
  
}

rct = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_unsell.csv', header=TRUE, na.strings=NA)
headTail(rct)

unsaleables = etl_unsaleables(rct)
headTail(unsaleables)

write.csv(unsaleables, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/unsaleables_upload.csv')



















etl_breakage = function(brk) {
  library(lubridate)
  
  names(brk) = c('Date', 'Product ID', 'Product', 'Cases', 'Cost', 'Type', 'Warehouse')
  
  r = brk$Type
  w = brk$Warehouse
  
  brk$Type = ifelse(r == 3 & w == 2, 'Warehouse STL', 
                    ifelse(r == 3 & w == 1, 'Warehouse KC', 
                           ifelse(r == 4 & w == 2, 'Driver STL',
                                  ifelse(r == 4 & w == 1, 'Driver KC', 
                                         ifelse(r == 5 & w == 1, 'Driver SPFD', 
                                                ifelse(r == 5 & w == 2, 'Driver COL',
                                                       ifelse(r == 3 & w == 5, 'Warehouse SPFD', 
                                                              ifelse(r == 3 & w == 3, 'Warehouse COL', 
                                                                     ifelse(is.na(w) & r == 3, 'Warehouse UNSPECIFIED',
                                                                            ifelse(is.na(w) & r == 4, 'Driver UNSPECIFIED',
                                                                                   ifelse(is.na(w) & r == 5, 'Driver MMO',
                                                                                          ifelse(r == 7, 'Supplier','UNSPECIFIED'))))))))))))
                    
  brk$Warehouse = ifelse(w == 2, 'STL', 
                         ifelse(w == 1, 'KC', 
                                ifelse(w == 3, 'COL', 
                                       ifelse(w == 5, 'SPFD', 
                                              ifelse(w == 4, 'CAPE',
                                                     ifelse(is.na(w), 'NOT IDENTIFIED', 'NOT IDENTIFIED'))))))   
  
  brk$Date = as400Date(brk$Date)
  
  brk$Cost = round(-1 * brk$Cost, 2)
  brk$Cases = round(-1 * brk$Cases, 2)
  
  brk$Year = year(brk$Date)
  brk$Month = month(brk$Date, label=TRUE, abbr=FALSE)
  
  brk              
   
}  


brk = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_breaks.csv', header=TRUE)

breakage = etl_breakage(brk)
headTail(breakage)

write.csv(breakage, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/breakage_upload.csv')





















etl_customers = function(customers) {
  library(stringr)
  days = as.character(customers$Ship.Days)
  days = str_pad(days, 7, pad='0')
  customers$Ship.Days = days
  
  customers$SUNDAY.PLAN = sun = ifelse(substrRight(days, 1) == 1, "Y", "N")
  customers$SATURDAY.PLAN = sat = ifelse(substrLeft(substrRight(days, 2), 1) == 1, "Y", "N")
  customers$FRIDAY.PLAN = fri = ifelse(substrLeft(substrRight(days, 3), 1) == 1, "Y", "N")
  customers$THURSDAY.PLAN= thurs =  ifelse(substrLeft(substrRight(days, 4), 1) == 1, "Y", "N")
  customers$WEDNESDAY.PLAN = wed =  ifelse(substrLeft(substrRight(days, 5), 1) == 1, "Y", "N")
  customers$TUESDAY.PLAN = tue = ifelse(substrLeft(substrRight(days, 6), 1) == 1, "Y", "N")
  customers$MONDAY.PLAN = mon =  ifelse(substrLeft(substrRight(days, 7), 1) == 1, "Y", "N")
  
  customers
}


customers = read.csv('C:/Users/pmwash/Desktop/Disposable Docs/Customers_edit.csv', header=TRUE)


cust = etl_customers(customers)
headTail(cust)

write.csv(cust, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/customer_upload.csv')


























# query is pw_offday
# 
# deliveries = read.csv("N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_offday.csv", header=TRUE); head(deliveries)
# weeklookup = read.csv("N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_offday_weeklookup.csv", header=TRUE)

# next time may 16 - x already got 15th

off_day_etl = function(deliveries, weeklookup) {
  library(lubridate)
  library(dplyr)
  library(stringr)
  source('C:/Users/pmwash/Desktop/R_files/Data Input/Helper.R')
  
  d = deliveries
  w = weeklookup
  
  names(d) = c('Date', 'Invoice', 'Customer', 'Call', 'Priority', 
               'Warehouse', 'Cases', 'Dollars', 'Ship', 'Salesperson', 
               'Ship.Week.Plan', 'Merchandising', 'On.Premise', 
               'Customer.Setup')
  
  date = d$Date = as400Date(d$Date)
  w$Date = as.character(strptime(weeklookup$Date, format="%m/%d/%Y"))

  d = merge(d, w, by='Date', all_x=TRUE)
  
  weekday = d$Weekday = wday(date, label=TRUE, abbr=TRUE)
  week_plan = d$Ship.Week.Plan
  week_shipped = d$Ship.Week
  month = month(date)
  setup_month = str_pad(as.character(d$Customer.Setup), 4, pad='0')
  setup_month = month(as.numeric(substrLeft(setup_month, 2)))
  year = year(date)
  s = substrRight(as.character(d$Customer.Setup), 2)
  this_century = as.numeric(s) < 20
  setup_year = ifelse(this_century == TRUE, 
         as.numeric(as.character(paste0("20", s))), 
         as.numeric(as.character(paste0("19", s))))
  days = as.character(d$Ship)
  days = d$Ship = str_pad(days, 7, pad='0')
  
  
  mon =  ifelse(substrLeft(substrRight(days, 7), 1) == 1, 'M', '_')
  tue = ifelse(substrLeft(substrRight(days, 6), 1) == 1, 'T', '_')
  wed =  ifelse(substrLeft(substrRight(days, 5), 1) == 1, 'W', '_')
  thu =  ifelse(substrLeft(substrRight(days, 4), 1) == 1, 'R', '_')
  fri = ifelse(substrLeft(substrRight(days, 3), 1) == 1, 'F', '_')
  sat = ifelse(substrLeft(substrRight(days, 2), 1) == 1, 'S', '_')
  sun = ifelse(substrRight(days, 1) == 1, 'S', '_')

  d$Delivery.Days = deldays = paste0(mon, tue, wed, thu, fri, sat, sun)
  d$Customer.Setup = paste0(str_pad(as.character(setup_month), 2, pad=0), '-', as.character(setup_year))
  
  if (week_plan != '') {
    if (week_plan != week_shipped) {
      off = 'Y'
    } else if (week_plan == week_shipped) {
        off = ifelse(mon=='M' & weekday=='Mon', 'N', 
                     ifelse(tue=='T' & weekday=='Tues', 'N',
                            ifelse(wed=='W' & weekday=='Wed', 'N', 
                                   ifelse(thu=='R' & weekday=='Thurs', 'N',
                                          ifelse(fri=='F' & weekday=='Fri', 'N', 
                                                 ifelse(sat=='S' & weekday=='Sat', 'N', 
                                                        ifelse(sun=='S' & weekday=='Sun', 'N', 'Y')))))))
    } 
  } else if (week_plan == '') {
      off = ifelse(mon=='M' & weekday=='Mon', 'N', 
                   ifelse(tue=='T' & weekday=='Tues', 'N',
                          ifelse(wed=='W' & weekday=='Wed', 'N', 
                                 ifelse(thu=='R' & weekday=='Thurs', 'N',
                                        ifelse(fri=='F' & weekday=='Fri', 'N', 
                                               ifelse(sat=='S' & weekday=='Sat', 'N', 
                                                      ifelse(sun=='S' & weekday=='Sun', 'N', 'Y')))))))
  } else {
      off = 'N'
  }

  d$Off.Day = off
   
  
  off_day_d = d %>% filter(Off.Day == 'Y')
  rm(d)
  #headTail(off_day_d, 100)
  week_plan = off_day_d$Ship.Week.Plan
  whse = off_day_d$Warehouse
  call = off_day_d$Call

  off_day_d$Warehouse = ifelse(whse==1, 'KC', 
                               ifelse(whse==2, 'STL', 
                                      ifelse(whse==3, 'COL', 
                                             ifelse(whse==4, 'CAPE', 
                                                    ifelse(whse==5, 'SPFD', '')))))
  
  off_day_d$Call = ifelse(call==1, 'Customer Call', 
                          ifelse(call==2, 'ROE/EDI',
                                 ifelse(call==3, 'Salesperson Call',
                                        ifelse(call==4, 'Telesales', 'Not Specified'))))
  
  ship_flag = off_day_d$Ship
  n_ship_days = sapply(strsplit(ship_flag, split=''), function(x) sum(as.numeric(x)))
  
  off_day_d$Tier = ifelse(week_plan=='A' | week_plan=='B', 'Tier 4', 
                          ifelse(n_ship_days==1 & (week_plan!='A' | week_plan!='B'), 'Tier 3',
                                 ifelse(n_ship_days==2, 'Tier 2',
                                        ifelse(n_ship_days>=3, 'Tier 1', 'Tier 4'))))
  
  off_day_d$Year = year(off_day_d$Date)
  
  new = off_day_d$Customer.Setup
  now_m = month(off_day_d$Month)
  now_y = off_day_d$Year
  
  setup_monthx = str_pad(as.character(off_day_d$Customer.Setup), 4, pad='0')
  setup_monthx = month(as.numeric(substrLeft(setup_monthx, 2)))
  sx = substrRight(as.character(off_day_d$Customer.Setup), 2)
  this_centuryx = as.numeric(sx) < 20
  setup_yearx = ifelse(this_centuryx == TRUE, 
                      as.numeric(as.character(paste0("20", sx))), 
                      as.numeric(as.character(paste0("19", sx))))
  
  
  off_day_d$New.Customer = ifelse(setup_monthx == now_m & setup_yearx == now_y, 'YES', 'NO')
  
  #off_day_d = filter(off_day_d, New.Customer != 'YES')
  
  da_colz = c('Date', 'Invoice', 'Call', 'Salesperson', 'Customer', 
              'New.Customer', 'On.Premise', 'Tier', 'Cases', 'Dollars', 
              'Priority', 'Warehouse', 'Weekday',
              'Delivery.Days', 'Month', 'DOTM', 'Year', 'Week',
              'Ship.Week', 'Ship.Week.Plan', 'Merchandising')
  off_day_d = off_day_d[, da_colz]
  
  names(off_day_d) = c('Date', 'Invoice', 'Call', 'Salesperson', 'Customer', 
                       'NewCustomer', 'OnPremise', 'Tier', 'Cases', 'Dollars', 
                       'Priority', 'Warehouse', 'Weekday',
                       'DeliveryDays', 'Month', 'DOTM', 'Year', 'Week',
                       'ShipWeek', 'ShipWeekPlan', 'Merchandising')
  
  
  off_day_d # headTail(off_day_d, 30)
  # write.csv(off_day_d, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/deliveries_upload2.csv')

}



deliveries = read.csv("N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_offday.csv", header=TRUE)
weeklookup = read.csv("N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_offday_weeklookup.csv", header=TRUE)

headTail(deliveries)
headTail(weeklookup)

off_days = off_day_etl(deliveries, weeklookup)
headTail(off_days, 50)



write.csv(off_days, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/deliveries_upload.csv')



























etl_po_lines = function(po) {
  library(lubridate)
  library(dplyr)
  
  names(po) = c('PO', 'Line', 'Date', 'Product', 'Supplier', 'Ordered', 'Received', 'Cost', 'Warehouse')
  
  po$Date = as400Date(po$Date)
  po$Month = month(po$Date, label=TRUE, abbr=FALSE)
  po$Year = year(po$Date)
  
  whse = po$Warehouse
  po$Warehouse = ifelse(whse==1, 'KC', 
                        ifelse(whse==2, 'STL', 
                               ifelse(whse==3, 'COL', 
                                      ifelse(whse==4, 'CAPE', 
                                             ifelse(whse==5, 'SPFD', '')))))
  
  po = arrange(po, Date)
  
  po
}


po = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/po_lines.csv', header=TRUE); head(po)

po_lines = etl_po_lines(po)
headTail(po_lines, 50)



write.csv(po_lines, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/po_lines_upload.csv')














etl_transfers = function(transfers) {
  library(lubridate)
  
  t = transfers
  
  names(t) = c('Date', 'Priority', 'Product', 'Cost', 'Cases', 'Warehouse', 'Supplier', 'Customer')
  
  whse = t$Warehouse
  
  t$Date = dat = as400Date(t$Date)
  t$Month = month(dat, label=TRUE, abbr=FALSE)
  t$Year = year(dat)
  
  t$Warehouse = ifelse(whse==1, 'KC', 
                        ifelse(whse==2, 'STL', 
                               ifelse(whse==3, 'COL', 
                                      ifelse(whse==4, 'CAPE', 
                                             ifelse(whse==5, 'SPFD', '')))))
  
  t
}

transfers = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/pw_trnsfer.csv', header=TRUE); head(transfers)

transfers = etl_transfers(transfers)
headTail(transfers, 50)



write.csv(transfers, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/transfers_upload.csv')


























etl_empty_keg_transfers = function(empty_keg_transfers) {
  library(lubridate)
  
  t = empty_keg_transfers
  
  names(t) = c('Date', 'Product', 'Class', 'Cost', 'Kegs', 'Warehouse', 'Customer')
  
  whse = t$Warehouse
  cls = t$Class
  
  t$Date = dat = as400Date(t$Date)
  t$Month = month(dat, label=TRUE, abbr=FALSE)
  t$Year = year(dat)
  
  t$Warehouse = ifelse(whse==1, 'KC', 
                       ifelse(whse==2, 'STL', 
                              ifelse(whse==3, 'COL', 
                                     ifelse(whse==4, 'CAPE', 
                                            ifelse(whse==5, 'SPFD', '')))))
  
  t$Class = ifelse(cls == 53, 'Keg Wine',
                   ifelse(cls == 59, 'Keg Cider', 
                          ifelse(cls == 85, 'Keg Beer', 
                                 ifelse(cls == 86, 'Keg Beer', 
                                        ifelse(cls == 87, 'Keg Beer Non-Deposit', 
                                               ifelse(cls == 88, 'Keg Beer High Alcohol', 'Not Specified'))))))
  
  t
}

empty_keg_transfers = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/empty_keg_transfers.csv', header=TRUE); head(empty_keg_transfers)

empty_keg_transfers = etl_empty_keg_transfers(empty_keg_transfers)
headTail(empty_keg_transfers, 50)



write.csv(empty_keg_transfers, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/empty_keg_transfers_upload.csv')








































#pwoos is backup for pwoostock

etl_out_of_stock = function(out_of_stock) {
  library(lubridate)
  
  t = out_of_stock
  
  names(t) = c('Date', 'Product', 'Warehouse', 'Cost', 'Cases', 'Back.Orders.Cases', 
               'YTD.Sales.Cases', 'Cases.On.Order', 'Cases.On.Hand', 'Cases.Reserved')
  
  t$Cost = round(t$Cost, 2)
  
  whse = t$Warehouse
  
  t$Date = dat = as400Date(t$Date)
  t$Month = month(dat, label=TRUE, abbr=FALSE)
  t$Year = year(dat)
  
  t = arrange(t, Product, Date)
  
  t$Warehouse = ifelse(whse==1, 'KC', 
                       ifelse(whse==2, 'STL', 
                              ifelse(whse==3, 'COL', 
                                     ifelse(whse==4, 'CAPE', 
                                            ifelse(whse==5, 'SPFD', '')))))
  
  headTail(t, 50)
  t %>% filter(Cases.Reserved > 0) %>% arrange(desc(Product))
  t %>% filter(Back.Orders.Cases > 0) %>% arrange(desc(Back.Orders.Cases), desc(Product))
  
  t
}

out_of_stock = read.csv('N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/out_of_stock.csv', header=TRUE); head(out_of_stock)

out_of_stock = etl_out_of_stock(out_of_stock)
headTail(out_of_stock, 50)



write.csv(out_of_stock, 'N:/Operations Intelligence/Monthly Reports/Data/Reporting/Transfer Files/Output/out_of_stock_upload.csv')


















# pw_custpups



# pw_slstakes

















































