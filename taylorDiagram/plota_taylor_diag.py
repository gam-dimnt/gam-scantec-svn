#! /usr/bin/env python
"""
Objetivo:
- Script para ler as tabelas de estatísticas do SCANTEC e plotar 
o diagrama de Taylor baseado no RMSE (raiz do erro quadrático médio)
e no ACOR (correlação de anomalia)

Dependências:
- taylorDiagram.py (https://gist.github.com/ycopin/3342888)
- matplotlib;
- numpy;
- sys;

Uso:
$ ./plota_taylor_diag.py 2013010100 2013013118 VTMP-500 CTRL EnKF EnSRF NCEP NCEP

No exemplo acima, estão sendo informados junto com o script as seguintes opções:
- 2013010100: data inicial
- 2013013118: data final
- VTMP-500..: nome da variável a ser avaliada
- EnSRF.....: nome da pasta que contém os arquivos com as estatísticas do EnSRF
- EnKF......: nome da pasta que contém os arquivos com as estatísticas do EnKF
- NCEP......: nome da pasta que contém os arquivos com as estatísticas do NCEP
- CTRL......: nome da pasta que contém os arquivos com as estatísticas do CTRL

Observações:
- As data inicial e final são aquelas que estão nos nomes dos arquivos com as
estatísticas. Por exemplo: RMSEEXP01_20130101002013013118T.scam;
- Pelo menos dois experimentos devem ser indicados para plotar o diagrama de Taylor;
- Nesta versão, ainda não se está considerando uma referência real (análise independente,
reanálise, climatologia independente ou observação). A referência é então um dos experimentos
indicados.

TODO:
- Implementar função para controle dos argumentos de entrada;
- Definir precisão das médias (rmse e acor);
- Consertar os raios dos experimentos (estão maiores/menores do que deveriam ser).

Histórico:
- XX/10/2016: versão inicial;
- 08/11/2016: modificada a aparencia do gráfico (posição e tamanho das fontes e legendas);
              modificada a forma como a lista de experimentos é armazenada (evita ordem aleatória);
              adicionado raio do experimento de referência (indica o valor de correlação de anomalia);
- 07/05/2017: início do versionamento (inclui tabelas exemplos do SCANTEC);

Carlos Frederico Bastarz (carlos.frederico@cptec.inpe.br, 26/10/2016)
"""

import sys
import numpy as np
from taylorDiagram_mod import TaylorDiagram
import matplotlib.pyplot as plt

global datai, dataf, exps, ref_name, varname, nexps

rmse_experimetos = {}
acor_experimentos = {}
rmse_referecia = {}
acor_refencia = {}

exps = []
ref_exps = []
instrucaoviaprompt = sys.argv #recebe o argumento via linha de comando
len_args = len(instrucaoviaprompt) #recebe o tamanho do argumento via parametro

for i in range(len_args-1,3,-1): # os quatro primeiros args. (0,1,2,3) sao o nome do script, as duas datas e o nome da variavel
  exps.append(sys.argv[i])

datai = sys.argv[1]
dataf = sys.argv[2]
varname = sys.argv[3]

nexps = len(exps)

myorder = list(range(nexps))
exps = [exps[i] for i in myorder] # reordena a lista para evitar que a legenda seja plotada em ordem aleatória


# Verifica qual dos experimentos indicados é a referência:
# - Se um experimento for indicado mais de uma vez, então 
#   ele é a referência:

testListExps = {}

for exp in exps:  #Modificar esse codigo tornar mais prático
  try:
    testListExps[exp] += 1
  except:
    testListExps[exp] = 1

ref_name = list(testListExps.keys())[list(testListExps.values()).index(2)] # Está fixo com 2.
ref_exps.append(ref_name)

exps_list = [x for x in exps if x not in ref_exps] # Escreve uma lista apenas com os nomes dos experimentos, sem a referencia:
nexps_list = len(exps_list)

def assembly_fnames(datai,dataf,exps):
  """
  Nesta função é montado o dicionário exps_fnames.
  Nele, as informações são armazenadas da seguinte forma:
  {
  'EnSRF': ('./EnSRF/VIESEXP01_20130101002013013118T.scam', 
            './EnSRF/RMSEEXP01_20130101002013013118T.scam', 
            './EnSRF/ACOREXP01_20130101002013013118T.scam'),
   'CTRL': ('./CTRL/VIESEXP01_20130101002013013118T.scam', 
            './CTRL/RMSEEXP01_20130101002013013118T.scam', 
            './CTRL/ACOREXP01_20130101002013013118T.scam'), 
   'NCEP': ('./NCEP/VIESEXP01_20130101002013013118T.scam', 
            './NCEP/RMSEEXP01_20130101002013013118T.scam', 
            './NCEP/ACOREXP01_20130101002013013118T.scam'),
   'EnKF': ('./EnKF/VIESEXP01_20130101002013013118T.scam', 
            './EnKF/RMSEEXP01_20130101002013013118T.scam', 
            './EnKF/ACOREXP01_20130101002013013118T.scam')
  }
  Ou seja, são criadas as keys EnSRF, CTRL, NCEP e EnKF (informadas
  pela linha de comando) e para cada uma delas, são formados e 
  atribuídos os nomes dos arquivos com as estatísticas de interesse.
  Esse dicionário será utilizado posteriormente para abrir um ou
  mais arquivos entre aqueles que o SCANTEC escreve.

  Observação: não é feito nenhum tipo de verificação dos arquivos.
  """

  global fname_vies, fname_rmse, fname_acor, exps_fnames

  exps_fnames = dict() 
  for j in range(len(exps)):

    exp = exps[j]

    fname_vies = "./" + exp + "/VIESEXP01_" + datai + dataf + "T.scam"
    fname_rmse = "./" + exp + "/RMSEEXP01_" + datai + dataf + "T.scam"  
    fname_acor = "./" + exp + "/ACOREXP01_" + datai + dataf + "T.scam"
    #fname_mean = "./" + exp + "/MEANEXP01_" + datai + dataf + "T.scam"

    exps_fnames[exp] = fname_vies, fname_rmse, fname_acor#, fname_mean


def read_file(fname):
  """
  Nesta função são lidos propriamente os arquivos de cada key do dicionário
  exps_fnames. Note que a primeira linha é ignorada e que apenas as colunas
  de 0 a 22 são lidas (o Python inicia a contagem em 0; a coluna 0 contém
  apenas os tempos de previsão). A opção unpack=True, faz com que os dados
  sejam lidos por colunas.

  Observação: não é feito nenhum tipo de verificação dos arquivos.
  """
  global data_table

  data_table = np.loadtxt(fname,skiprows=1, unpack=True)

def read_varc(data_table):
  global exp_data_table, vnames, vname

  vnames = {
            '%Previsao': [ 0 ,''],
            'VTMP-925':  [ 1 ,'Temperatura Virtual em 925hPa'], 
            'VTMP-850':  [ 2 ,'Temperatura Virtual em 850hPa'],
            'VTMP-500':  [ 3 ,'Temperatura Virtual em 500hPa'],
            'TEMP-850':  [ 4 ,'Temperatura do Ar em 925hPa'],
            'TEMP-500':  [ 5 ,'Temperatura do Ar em 850hPa'],
            'TEMP-250':  [ 6 ,'Temperatura do Ar em 500hPa'],
            'PSNM-000':  [ 7 ,'Pressão em Superfície'],
            'UMES-925':  [ 8 ,'Umidade Específica em 925hPa'],
            'UMES-850':  [ 9 ,'Umidade Específica em 850hPa'],
            'UMES-500': [ 10 ,'Umidade Específica em 500hPa'],
            'AGPL-925': [ 11 ,'Água Precipitável em 925hPa'],
            'ZGEO-850': [ 12 ,'Altura Geopotencial em 850hPa'],
            'ZGEO-500': [ 13 ,'Altura Geopotencial em 500hPa'],
            'ZGEO-250': [ 14 ,'Altura Geopotencial em 250hPa'],
            'UVEL-850': [ 15 ,'Vento Zonal em 850hPa'],    
            'UVEL-500': [ 16 ,'Vento Zonal em 500hPa'],    
            'UVEL-250': [ 17 ,'Vento Zonal em 250hPa'],    
            'VVEL-850': [ 18 ,'Vento Meridional em 850hPa'],
            'VVEL-500': [ 19 ,'Vento Meridional em 500hPa'],
            'VVEL-250': [ 20 ,'Vento Meridional em 250hPa'],
            'PREC-000': [ 21 ,'Precipitação Convenctiva'],
            'PREV-000': [ 22 ,'Precipitação Estratiforme'],
           }

  vname = vnames[varname] # A Variavel vname recebe uma linha da variavel passada por parametro, assim essa variavel recebe um dicionario contento a chave e os seus valores
  exp_data_table = data_table[(vname[0])] # Nessa linha a variavel exp_data_table recebbe a coluna da variavel analisada

def samples(exps_fnames):#SAMPLES SÃO AS AMOSTRAS OU SEJA OS EXPERIMENTOS
  """
  Nesta função são calculados os samples que serão utilizados no plot do
  diagrama de Taylor. O samples é também um dicionário e será organizado 
  da seguinte maneira (exemplo):
  {
  'TEMP-850': array([['10.0376309381', '0.882568506839', 'CTRL'],
                    ['10.0335339753', '0.880217920479', 'NCEP'],
                    ['10.0297731423', '0.90174622461',  'EnKF']])
  }
  Para cada variável lida de dentro dos arquivos de estatísticas do SCANTEC,
  é armazanada a seguinte tripleta: 
  desvio padrão (ou rms), coeficiente de correlação (ou correlação de anomalia) e nome do exp.
  """
  
  global refstd, refacor, model, samples_vars, samples, stdrefs, acorefs, name_exp

  samples = dict()
  stdrefs = dict()
  acorefs = dict()

  ref = exps_fnames[ref_name] #lista com os valores da referencia
 
  read_file(ref[1]) # arquivo rmse
  read_varc(data_table)
  refstd = np.mean(exp_data_table) #A função np.mean Calcula a Média dos valor selecionados
  stdrefs[varname] = refstd
  rmse_referecia[0] = exp_data_table  # Nessa linha e feito um dicionario com o valores da refencia sobre o RMSE

  read_file(ref[2])#  arquivo acor
  read_varc(data_table)
  refacor = np.mean(exp_data_table)
  acorefs[varname] = refacor
  acor_refencia[0] = exp_data_table # Nessa linha e feito um dicionario com o valores da refencia sobre a Correlação de Anomalia

  for i in range(len(exps_list)):   
    name_exp = exps_list[i]
    m = exps_fnames[exps_list[i]] 

    read_file(m[1]) # arquivo do rmse dos modelos
    read_varc(data_table)
    mstd = np.mean(exp_data_table)
    rmse_experimetos[i] = exp_data_table # Nessa linha cria um dicionario com as tabela referente a variavel para cada modelo sobre o valor do RMSE

    
    read_file(m[2]) # arquivo da correlaçao de anomalias dos modelos
    read_varc(data_table)
    macor = np.mean(exp_data_table)    
    samples_vars = np.array([mstd, macor, exps_list[i]])
    samples.setdefault(varname,[]).append(samples_vars)
    acor_experimentos[i] = exp_data_table  # Nessa linha cria um dicionario com as tabela referente a variavel para cada modelo sobre o valor da Correlação de Anomalia

def plota_taylor(samples,stdrefs,acorefs):
  """
  Nesta função é chamada a classe TaylorDiagram.
  """

  # Mais cores em: https://gist.github.com/endolith/2719900 

  colors = plt.matplotlib.cm.Set1(np.linspace(0,1,len(samples[varname])))

  fig = plt.figure(figsize=(5,5))
  
  for varlev in [varname]:
      
      dia = TaylorDiagram(stdrefs[varlev], acorefs[varlev], colors, fig=fig, label=ref_name)
  
      # Add samples to Taylor diagram
      for i,(stddev,corrcoef,name) in enumerate(samples[varname]):
      
          dia.add_sample(stddev, corrcoef,colors[i],
                         marker='$%d$' % (i+1), ms=7, ls='',
                         mfc=colors[i], mec=colors[i], 
                         label=name)
      
      # Add RMS contours, and label them
      # contours = dia.add_contours(levels=5, colors='0.5') # 5 levels
      # dia.ax.clabel(contours, inline=1, fontsize=10, fmt='%.1f')

      # Título
      if (datai == dataf):
        dia._ax.set_title(vnames[varlev][1] + '\n(' + datai + ')', y=1.025)
      else:
        dia._ax.set_title(vnames[varlev][1] + '\n(' + datai + ' - ' + dataf + ')', y=1.025)
  
  fig.legend(dia.samplePoints,
             [ p.get_label() for p in dia.samplePoints ],
             numpoints=1, prop={'size':6}, bbox_to_anchor=(0.95,0.9))

  if (datai == dataf):
    plt.savefig(ref_name + '_' + varname + '_' + datai + '.png')
  else:
    plt.savefig(ref_name + '_' + varname + '_' + datai + '-' + dataf + '.png')

def precisao_acuracia(): # Nesse método são calculados quais valores dos modelos são mais aproximado da referência assim podemos identificar qual modelo apresenta melhor precisão e acurácia

  res_rmse = []
  res_acor = []
  lista_r = []
  lista_a = []
  x = rmse_referecia.get(0)
  y = acor_refencia.get(0)

  """
      Nesse Bloco são calculados a diferença entra os valores dos modelos em relação a referência.
      Sendo esses valores armazenados em uma lista contendo outras listas, ou seja lista dentro de lista.

      Exemplo utilizando a seguinte instrução via prompt de comando: "./plota_taylor_diag.py 2013010100 2013013118 VTMP-500 CTRL CTRL EnKF EnSRF NCEP"

      Diferença do RMSE em relação a referência:
      [[0.122, 0.055000000000000049, 0.025999999999999912, 0.015000000000000124, 0.050000000000000044, 0.066999999999999948, 0.084999999999999964, 
           0.10299999999999998, 0.12799999999999989, 0.14100000000000001, 0.15600000000000014, 0.16599999999999993, 0.17100000000000026, 0.17200000000000015, 
           0.17300000000000004, 0.17300000000000004, 0.17500000000000027, 0.17700000000000005, 0.18400000000000016, 0.18699999999999983],
      [0.11100000000000004, 0.11899999999999999, 0.1080000000000001, 0.097000000000000086, 0.085000000000000187, 0.075999999999999845, 0.066999999999999948,
           0.05699999999999994, 0.050999999999999934, 0.042000000000000037, 0.036000000000000032, 0.030000000000000249, 0.024999999999999911, 0.020000000000000018,
           0.016999999999999904, 0.017999999999999794, 0.021000000000000352, 0.027000000000000135, 0.036000000000000032, 0.044000000000000039],
      [0.062, 0.05699999999999994, 0.050000000000000044, 0.045000000000000151, 0.042000000000000037, 0.042999999999999927, 0.040000000000000036, 0.038999999999999924,
           0.038999999999999924, 0.038000000000000034, 0.037000000000000366, 0.034000000000000252, 0.032999999999999918, 0.032000000000000028, 0.032999999999999918,
           0.036000000000000032, 0.037000000000000366, 0.039000000000000146, 0.044000000000000039, 0.046999999999999709]]

      Diferença da Correlação de Anomalias em relação a referência:
      [[0.0040000000000000036, 0.0020000000000000018, 0.0020000000000000018, 0.0010000000000000009, 0.0020000000000000018, 0.0020000000000000018, 0.0040000000000000036,
           0.0050000000000000044, 0.0070000000000000062, 0.009000000000000008, 0.010000000000000009, 0.01100000000000001, 0.012000000000000011, 0.012000000000000011, 
           0.013000000000000012, 0.013000000000000012, 0.014000000000000012, 0.015000000000000013, 0.016000000000000014, 0.017000000000000015], 
      [0.0030000000000000027, 0.0060000000000000053, 0.0060000000000000053, 0.0070000000000000062, 0.0070000000000000062, 0.0070000000000000062, 0.0069999999999998952,
           0.0070000000000000062, 0.0060000000000000053, 0.0060000000000000053, 0.0050000000000000044, 0.0050000000000000044, 0.0040000000000000036, 0.0030000000000000027, 
           0.0030000000000000027, 0.0030000000000000027, 0.0030000000000000027, 0.0040000000000000036, 0.0050000000000000044, 0.0060000000000000053], 
      [0.0020000000000000018, 0.0030000000000000027, 0.0020000000000000018, 0.0030000000000000027, 0.0030000000000000027, 0.0030000000000000027, 0.0030000000000000027,
           0.0030000000000000027, 0.0030000000000000027, 0.0030000000000000027, 0.0030000000000000027, 0.0020000000000000018, 0.0020000000000000018, 0.0020000000000000018,
           0.0010000000000000009, 0.0020000000000000018, 0.0020000000000000018, 0.0020000000000000018, 0.0030000000000000027, 0.0040000000000000036]]

    """

  for i in range(len(exps_list)): 
    
    tmp_r = []
    tmp_a = []
    xx = rmse_experimetos.get(i)
    yy = acor_experimentos.get(i)

    for j in range(1,len(x),1):
      
      if(xx[j]>x[j]):
        r = xx[j]%x[j]
        tmp_r.append(r)
      else:
        r = x[j]%xx[j]
        tmp_r.append(r)
      
      if(yy[j]>y[j]):
        a = yy[j]%y[j]
        tmp_a.append(a)
      else:
        a = y[j]%yy[j]
        tmp_a.append(a)

    res_rmse.append(tmp_r[:])
    res_acor.append(tmp_a[:])
  
  for k in range(0,len(x)-1,1):
    lr = []
    la = []

    for l in range(0,len(res_rmse),1):
      a = res_rmse[l][k]
      b = res_acor[l][k]
      lr.append(a)
      la.append(b) 
    lista_r.append(lr)
    lista_a.append(la)

  for m in range(0,len(lista_r),1):
    valor_min = min(lista_r[m])
    for n in range(0,len(exps_list),1):
        if valor_min == lista_r[m][n]:
          print("Modelo mais preciso as",(m+1)*6,"horas",exps_list[n])
  print()

  for m in range(0,len(lista_r),1):
    valor_max = max(lista_r[m])
    for n in range(0,len(exps_list),1):
        if valor_max == lista_r[m][n]:
          print("Modelo menos preciso as",(m+1)*6,"horas",exps_list[n])
  print()

  for m in range(0,len(lista_a),1):
    valor_min = min(lista_a[m])
    for n in range(0,len(exps_list),1):
        if valor_min == lista_a[m][n]:
          print("Modelo mais acurado as",(m+1)*6,"horas",exps_list[n])
  print()

  for m in range(0,len(lista_a),1):
    valor_max = max(lista_a[m])
    for n in range(0,len(exps_list),1):
        if valor_max == lista_a[m][n]:
          print("Modelo menos acurado as",(m+1)*6,"horas",exps_list[n])
  print()

  
def main():

  assembly_fnames(datai,dataf,exps)

  samples(exps_fnames)

  plota_taylor(samples,stdrefs,acorefs)


  print("\n\n\n\n\n\n")
  print("Nome do Modelo de referencia: ",ref_name)
  print()
  print("Valores da variavel de Referecnia sobre RMSE: \n", rmse_referecia)
  print("\n\n")

  print("Valores da variavel de referência sobre CORRELAÇÂO DE ANOMALIAS: \n",acor_refencia)
  print("\n\n")
  print("nomes das experimentos: ", exps_list)
  print()
  print("dicionário RMSE dos Experimentos: \n",rmse_experimetos)
  print("\n\n")
  print("dicionário da Correlação de Anomalias dos Experimentos: \n",acor_experimentos)
  print("\n\n")

          #print("Experimento de Referecnia: ",ref_name)
          #print("Experimento Analisados: ", exps_list)
          #print("Variável a ser Analisada: ", varname)
          #print("Horário da Previsão:",(m+1)*6,"horas")
          #print("Valor da variavel de Referecnia", x[m+1])

  precisao_acuracia()

main()
