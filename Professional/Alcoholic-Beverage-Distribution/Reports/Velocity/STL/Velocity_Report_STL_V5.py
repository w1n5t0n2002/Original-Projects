'''
Velocity Report, STL
Re-Done September 2016
Ensure saved as Excel document UTF8
Do NOT pre-sort the data
Save to same place each time
Read in the xlsx file exported from Compleo
Separate out cases and bottles
Run velocity separation process
Print to file
Send to group
'''

import pandas as pd
from pandas import read_excel, Series, DataFrame
import numpy as np
from datetime import datetime as dt

raw = read_excel('C:/Users/pmwash/Desktop/Re-Engineered Reports/Velocity/Data/velocity_stl.xlsx',header=0)

ttl_btl = np.float64(input('Enter total bottles expected from Compleo export: '))#9259.37
ttl_cs = np.float64(input('Enter total cases expected from Compleo export: '))#270206


if dt.now().month == 1:
    last_mon = 12
else:
    last_mon = dt.now().month - 1
report_month = dt.now().replace(month=last_mon).strftime('%B')
if dt.now().month == 1:
    report_year = dt.now().year - 1
else:
    report_year = dt.now().year
report_month_year = str(report_month) + ' ' + str(report_year)# + ' Year to Date'


print('''


Expecting cases to be %.2f and bottles to be %.2f


''' % (ttl_cs,ttl_btl))

def pre_process_stl(raw):
    '''
    Accepts a .xls output from Compleo unformatted
    '''
    print('-'*100)
    print('Pre-processing raw Compleo export from the AS400.')
    print('-'*100)    
    
    print('\n\n\nRemoving whitespace from column names.')
    raw.columns = [x.strip().replace(' ','') for x in raw.columns]
    
    print('Locating the case/bottle split in the document to separate the two.') 
    find_btl_split = Series(raw['SIZE'].astype(str).tolist())
    find_btl_split = Series([x.strip().replace(' ','') for x in find_btl_split])
    
    find_case_split = Series(raw['BOTTLESALES'].astype(str).tolist())
    find_case_split = Series([x.strip().replace(' ','') for x in find_case_split])
    
    
    btl_end_ix = min(find_btl_split[find_btl_split == 'OTAL'].index)
    case_start_ix = min(find_case_split[find_case_split == 'CASESALES'].index)
    
    print('Splitting out cases from bottles.')
    btls = raw.loc[0:btl_end_ix-1].reset_index(drop=True)
    cases = raw.loc[case_start_ix:].reset_index(drop=True)
    
    print('Mapping column names.') 
    cases.columns = ['PRODUCT#', 'SIZE', 'ANDDESCRIPTION', 'CASESALES', 'PICKFREQUENCY', 'CSE.LOC.',
           'BTL.LOC.', 'BULK1', 'BOTTLESONHAND']
    
    print('Removing invalid data.')
    remove_rows_cases = cases['PRODUCT#'].astype(str).apply(lambda x: str.isnumeric(x) )
    cases = cases[remove_rows_cases == True].reset_index(drop=True)
    
    remove_rows_btls = btls['PRODUCT#'].astype(str).apply(lambda x: str.isnumeric(x) )
    btls = btls[remove_rows_btls == True].reset_index(drop=True)
    
    def replace_last(source_string, replace_what, replace_with):
        '''Replaces last occurrence of replace_what'''
        head, sep, tail = source_string.rpartition(replace_what)
        return head + replace_with + tail
    
    print('Formatting negative numbers so negative sign is before value.')
    btl_sales = btls['BOTTLESALES'].astype(str).tolist()
    btl_sales = [b.strip().replace(' ','') for b in btl_sales]
    btl_sales = [b.strip().replace(',','') for b in btl_sales]
    btl_sales = ['-' + replace_last(b,'-','')  if b.endswith('-') == True else b for b in btl_sales]
    btl_sales = Series(btl_sales)
    btls['BOTTLESALES'] = btl_sales.astype(np.float64)
    
    case_sales = cases['CASESALES'].astype(str).tolist()
    case_sales = [c.strip().replace(' ','') for c in case_sales]
    case_sales = [c.strip().replace(',','') for c in case_sales]
    case_sales = ['-' + replace_last(c,'-','')  if c.endswith('-') == True else c for c in case_sales]
    case_sales = Series(case_sales)
    cases['CASESALES'] = case_sales.astype(np.float64)
    
    print('Performing checks with expected values.')
    check_btls = np.sum(btls['BOTTLESALES'])
    check_cses = np.sum(cases['CASESALES'])
    
    print('\n\n\nTotal bottles: ', check_btls, '\n\nTotal cases: ', check_cses, '\n\n\n')
    
    cases.columns = ['PRODUCT#','SIZE','DESCRIPTION','CASESALES','PICKFREQUENCY','CSE.LOC.','BTL.LOC.','BULK1','BOTTLESONHAND']
    btls.columns = ['PRODUCT#','SIZE','DESCRIPTION','BOTTLESALES','PICKFREQUENCY','CSE.LOC.','BTL.LOC.','BULK1','BOTTLESONHAND']
    
    print('-'*100)
    print('Finished pre-processing data.')    
    print('-'*100)
    print('\n\n\n')
    
    return btls, cases



BTLS,CASES = pre_process_stl(raw)




def map_stl_lines(BTLS,CASES):
    '''
    Map STL Lines to locations
    '''
    print('-'*100)
    print('Mapping lines to the dataset.') 
    print('-'*100)
    
    CASES['CASELINE'] = CASES['CSE.LOC.'].astype(str).str[:1]
    c_lines = list()
    
    for i, c in enumerate(CASES['CASELINE']):
        if c == 'C':
            c_lines.append('C-Line')
        elif c == 'D':
            c_lines.append('D-Line')
        elif c == 'E':
            c_lines.append('E-Line')
        elif c == 'F':
            c_lines.append('F-Line')
        elif c == 'G':
            c_lines.append('G-Line')
        elif c == 'K':
            c_lines.append('KegRoom')
        elif c == 'W':
            c_lines.append('WineRoom')
        else:
            c_lines.append('OddBall-C')
    
    CASES['CASELINE'] = c_lines
    
    btl_line_indicator = Series(BTLS['BTL.LOC.'].astype(str).str[:1].tolist())
    bottle_lines = []
    
    for i, b in enumerate(btl_line_indicator):
        if b == 'A':
            bottle_lines.append('A Line')
        elif b == 'B':
            bottle_lines.append('B Line')
        else:
            bottle_lines.append('OddBall-B')
    
    BTLS['BOTTLELINE'] = bottle_lines

    return CASES, BTLS



CASES,BTLS = map_stl_lines(BTLS,CASES)




def extract_features(CASES, BTLS, production_days=18):
    '''Extracts features from the data'''
    
    CASES['CASE.SALES.PER.DAY'] = round(CASES.CASESALES / production_days,4)
    BTLS['BTL.SALES.PER.DAY'] = round(BTLS.BOTTLESALES / production_days,4)
    
    return CASES, BTLS



CASES, BTLS = extract_features(CASES, BTLS)




def create_summary(CASES, BTLS, production_days=18):
    '''Summarize case lines for STL'''
    print('-'*100)
    print('Creating summary.')
    print('-'*100)
    
    cs_count_items_on_line = CASES[['CASELINE','CASESALES']].groupby('CASELINE').count()
    cs_count_items_on_line.columns = ['N_SKUS']
    cs_volume_on_line = CASES[['CASELINE','CASESALES']].groupby('CASELINE').sum()
    cs_volume_on_line.columns = ['CASE_VOLUME']
    
    cs_summary = cs_count_items_on_line.join(cs_volume_on_line)
    cs_summary['VOLUME_PER_SKU'] = round(cs_summary.CASE_VOLUME / cs_summary.N_SKUS, 2)
    cs_summary['VOLUME_PER_DAY'] = round(cs_summary.CASE_VOLUME / production_days, 0)
    total_case_volume = cs_summary['CASE_VOLUME'].sum()
    cs_summary['PERCENT_TOTAL_VOLUME'] = round(cs_summary.CASE_VOLUME / total_case_volume, 4)
    
    btl_count_items_on_line = BTLS[['BOTTLELINE','BOTTLESALES']].groupby('BOTTLELINE').count()
    btl_count_items_on_line.columns = ['N_SKUS']
    btl_volume_on_line = BTLS[['BOTTLELINE','BOTTLESALES']].groupby('BOTTLELINE').sum()
    btl_volume_on_line.columns = ['BOTTLE_VOLUME']
    
    btl_summary = btl_count_items_on_line.join(btl_volume_on_line)
    btl_summary['VOLUME_PER_SKU'] = round(btl_summary.BOTTLE_VOLUME / btl_summary.N_SKUS, 2)
    btl_summary['VOLUME_PER_DAY'] = round(btl_summary.BOTTLE_VOLUME / production_days, 0)
    total_bottle_volume = btl_summary['BOTTLE_VOLUME'].sum()
    btl_summary['PERCENT_TOTAL_VOLUME'] = round(btl_summary.BOTTLE_VOLUME / total_bottle_volume, 4)
    
    print('\n\n\n')    
    
    return cs_summary, btl_summary




def write_stl_to_xlsx(CASES, BTLS, month):
    '''Write the output to file'''
    print('-'*100)
    print('Writing data to Excel file on the STL Common drive.')
    print('-'*100)    
    
    file_out = pd.ExcelWriter('N:/Operations Intelligence/Monthly Reports/Velocity/Velocity-'+month+'.xlsx', engine='xlsxwriter')
    workbook = file_out.book
    
    cs_summary, btl_summary = create_summary(CASES, BTLS)
    cs_summary.to_excel(file_out, sheet_name='Summary', index=True)
    btl_summary.to_excel(file_out, sheet_name='Summary', startrow=12, index=True)

    print('Defining number formats for later use.')    
    format_percent = workbook.add_format({'num_format': '0%'})
    
    summary_tab = file_out.sheets['Summary']
    summary_tab.set_column('A:A',11)
    summary_tab.set_column('B:B',9)
    summary_tab.set_column('C:C',16)
    summary_tab.set_column('D:E',19)
    summary_tab.set_column('F:F',24, format_percent)
    
    cs_lines = ['C-Line','D-Line','E-Line','F-Line','G-Line','OddBall-C','WineRoom']
    btl_lines = ['A Line','B Line','OddBall-B']
    
    for i, line in enumerate(cs_lines):
        new_df = DataFrame(CASES[CASES.CASELINE == line])
        
        new_df.reset_index(drop=True, inplace=True)
        print('Inputting %s as its own tab in the velocity report.' % line)
        tab_name = str(line)
        new_df.to_excel(file_out, sheet_name=tab_name,index=False)
        sheet = file_out.sheets[tab_name]
        sheet.set_column('A:B',10)
        sheet.set_column('C:C',48)
        sheet.set_column('D:D',12)
        sheet.set_column('E:E',15.2)
        sheet.set_column('F:H',8.5)
        sheet.set_column('I:I',16)
        sheet.set_column('J:J',9)
        sheet.set_column('K:K',19)
        
        
    for i, line in enumerate(btl_lines):
        new_df = DataFrame(BTLS[BTLS.BOTTLELINE == line])
        
        new_df.reset_index(drop=True, inplace=True)
        print('Inputting %s as its own tab in the velocity report.' % line)
        tab_name = str(line)
        new_df.to_excel(file_out, sheet_name=tab_name,index=False)
        sheet = file_out.sheets[tab_name]
        sheet.set_column('A:B',10)
        sheet.set_column('C:C',48)
        sheet.set_column('D:D',12)
        sheet.set_column('E:E',15.2)
        sheet.set_column('F:H',8.5)
        sheet.set_column('I:I',16)
        sheet.set_column('J:J',9)
        sheet.set_column('K:K',19)    
    
    file_out.save()
    print('\n\n\n')
    print('-'*100)
    print('Finished writing data to file.')
    print('-'*100)    

write_stl_to_xlsx(CASES, BTLS, month=report_month_year)
  





























# all_sizes = raw['SIZEANDDESCRIPTION'].tolist()
# keg_sizes = ["\\<1/6BL\\>","\\<1/2BL\\>","\\<1/4BL\\>","\\<20L\\>","\\<10.8G\\>","\\<15.5G\\>","\\<15L\\>",
# "\\<2.6G\\>","\\<19L\\>","\\<3.3G\\>","\\<4.9G\\>","\\<5.16G\\>","\\<5.2G\\>","\\<5.4G\\>","\\<19.5L\\>",
# "\\<50L\\>","\\<30L\\>","\\<5G\\>","\\<25L\\>"]
# keg_sizes = '(' + ')|('.join(keg_sizes) + ')'

# [re.match(k,a) for k,a in zip(keg_sizes,all_sizes)]

# re.match(keg_sizes,'1/6BL')


