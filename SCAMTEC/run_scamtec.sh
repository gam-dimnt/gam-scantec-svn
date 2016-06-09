#/bin/sh

#
#BOP
#--------------------------------------------------------------------#
#         Sistema de Avaliação de Modelos (SAM)                      #
#--------------------------------------------------------------------#
#
# !DESCRIPTION:
#Script para executar o SCAMTEC
#
# !CALLING SEQUENCE:
# ./run_scamtec.sh N
#                  
#                  N=1 TestCase utilizando dados do BRAMS 05km para janeiro de 2016
#                  N=2 Aberto ao usuário, por enquanto ele edita no run_scamtec.sh a data, os experimentos e o local dos dados 
#
#
#!Histórico de revisões: 
#      20-05-2016 - Lucas Amarante     - Versão inicial
#      24-05-2016 - Claudio Pavani     - TestCase BRAMS, execução do plot.gpl
#
#
#
#help#
#**********************************************************#
#                                                          #
#    Script para rodar os experimentos do SCAMTEC          #
#     							   #
#                                                          #
#**********************************************************#


 echo 
 echo " <<< INICIANDO TESTCASE SCAMTEC >>> " 
 echo 

#==========================================================================
#configuracao inicial das variaveis
#==========================================================================

#diretorio atual
dir_act=`pwd`

ARQlog=${dir_act}/exec_scamtec.log



#verifica parametros
if [ -z "${1}" ]; then
  echo ""
  echo "O Flag TestCase is not correctly setted. Use: "
  echo " - 1 para fazer um testCase do BRAMS "
  echo " - 2 para usar os dados desejados do usuario "
  echo " "
  echo ""   
else
  export TESTCASE=${1} 
  if [ $TESTCASE -gt 2 ]; then
    echo ""
    echo "O Flag TestCase is not correctly setted. Use: "
    echo " - 1 para fazer um testCase do BRAMS 5km "
    echo " - 2 para usar os dados desejados do usuario "
    echo " "
    echo " "
    echo "Para mais informacoes digite :"
    echo " "
    echo " > ./run_scamtec ajuda"
    echo ""
    exit 1
  fi
fi


case $TESTCASE in
  [1]) 

#Tempo
datai=2016010100
dataf=2016010300
passo_analise=06
passo_previsao=06
total_previsao=36

#Recorte
lat_low=-49.875 
lon_low=-82.625 
lat_up=11.375 
lon_up=-35.375 
dx=0.25  
dy=0.25 

#Referencia 
#Plugin modelo
pl_model_refer=11

#Arquivo (analise)
arq_refer=/scratchout/grupos/exp-dmd/home/exp-dmd/OPER.2016/05km/exp5kmM/%y4%m2%d200/grads/BRAMS5.exp5kmM_%y4%m2%d200-A-%y4-%m2-%d2-000000-g1.gra

#/scratchin/grupos/assim_dados/home/gdad/DataFix/OBS/testcase/SCAMTEC/BRAMS/5km/%y4%m2%d200/grads/BRAMS5.exp5kmM_%y4%m2%d200-A-%y4-%m2-%d2-000000-g1.gra

#Experimento
#Plugin experimento
pl_model_exper=11

#Arquivo (previsao)
arq_prev=/scratchout/grupos/exp-dmd/home/exp-dmd/OPER.2016/05km/exp5kmM/%y4%m2%d200/grads/BRAMS5.exp5kmM_%iy4%im2%id200-A-%fy4-%fm2-%fd2-%fh20000-g1.gra

#/scratchin/grupos/assim_dados/home/gdad/DataFix/OBS/testcase/SCAMTEC/BRAMS/5km/%y4%m2%d200/grads/BRAMS5.exp5kmM_%iy4%im2%id200-A-%fy4-%fm2-%fd2-%fh20000-g1.gra

#climatologia
use_climatologia=1

#precipitacao
use_precipitacao=0

#calculo EOF
use_eof=0
;;
 
 [2])
#Configuracao do usuario
#Tempo
datai=2016010100
dataf=2016010500
passo_analise=12
passo_previsao=12
total_previsao=120

#Recorte
lat_low=-49.875 
lon_low=-82.625 
lat_up=11.375 
lon_up=-35.375 
dx=0.4  
dy=0.4 

#Referencia 
#Plugin modelo
pl_model_refer=1

#Arquivo (analise)
arq_refer=/stornext/online6/assim_dados/paulo.dias/Backup_g3dvar_comMetopB/pos_datainout/TQ0299L064/%y4%m2%d2%h2/GPOSNMC%y4%m2%d2%h2%y4%m2%d2%h2P.icn.TQ299L064.grb

#Experimento
#Plugin experimento
pl_model_exper=1

#Arquivo (previsao)
arq_prev=/stornext/online6/assim_dados/paulo.dias/Backup_g3dvar_comMetopB/pos_datainout/TQ0299L064/%y4%m2%d2%h2/GPOSNMC%iy4%im2%id2%ih2%fy4%fm2%fd2%fh2P.fct.TQ299L064.grb

#climatologia
use_climatologia=1

#precipitacao
use_precipitacao=0

#calculo EOF
use_eof=0
;;



esac



#saida resultados
saida_results=/scratchout/grupos/assim_dados/home/claudio.pavani/saida_scamtec/


echo "=====================================" 
echo "Configuracoes iniciais:              " 
echo "Data inicial: ${datai}               "
echo "Data final:   ${dataf}               "
echo "=====================================" 
echo " "                                     


#=========================================================================

                                        

data=`date`
 
#Iniciando o procedimento
echo "Inicio do processamento: ${data}"  >> ${ARQlog}
echo "Inicio do processamento: ${data}"


#Entrando no diretorio
cd ${dir_act}/bin

echo
echo 'Criando o arquivo de controle .rc'
echo

INPUTDATA='$INPUTDATA'
cat <<EOT1 > scamtec.conf
$INPUTDATA
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
#                  SCAMTeC - GDAD/CPTEC/INPE - 2010                   !
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!

#======================================================================
#                          Runtime options
#
Starting Time: ${datai}                #Format  :: YYYYMMDDHH
Ending Time:   ${dataf}                #Format  :: YYYYMMDDHH
Analisys Time Step:  ${passo_analise}  #Format  :: HH
Forecast Time Step:  ${passo_previsao} #Format  :: HH
Forecast Total Time: ${total_previsao} #Format  :: HH
History Time:   48                     #Format  :: HH

#======================================================================
#                       DOMAIN SPECIFICATION
# Definition of Running Domain
# Specify the domain extremes in latitude and longitude
#
#              +----------------------------------+
#              |**********************************|
#              |**********************************|
#            L |*************** +--------------+ *|
#            A |*************** |              | *|
#            T |*************** |     Area     | *|
#            I | * +--------+ * |      02      | *|
#            T | * |        | * |              | *|
#            U | * |  area  | * |              | *|
#            D | * |   01   | * |              | *|
#            E | * |        | * +--------------+ *|
#              | * |        | ********************|
#              | * +--------+ ********************|
#              | *********************************|
#              +----------------------------------+
#                        L O N G I T U D E
#

run domain number: 1 # Number of areas to analise 

# domain of each area
#                    AREAS     1               2            3        4          5
#                 	1                 America Sul             Brasil   hemisferio sul  equatorial  norte
run domain lower left lat:     ${lat_low}      # -49.875    # -60.95   #  -35	   # -80    -20	        20
run domain lower left lon:     ${lon_low}      # -82.625    # -82.95   #  -80	   #   0      0	         0	
run domain upper right lat:    ${lat_up}       #  11.375    #  20.95   #   10	   # -20     20	        80
run domain upper right lon:    ${lon_up}       # -35.375    # -33.95   #  -30	   # 360     360       360   
run domain resolution dx:    	${dx}          #   0.25     #    0.1   #  0.4	   # 0.4 
run domain resolution dy:    	${dy}          #   0.25     #    0.1   #  0.4	   # 0.4 

#======================================================================
#                              Files to Analyse
#
#======================================
# Reference File
#
#         Name diretory File_Name_with_mask
#

Reference model: ${pl_model_refer}
Reference file:  ${arq_refer}
Reference label: REFER

#======================================
# Experiment Files
#

Number of Experiments: 1

Experiments:
#ModelId Name Diretory File_Name_with_mask
${pl_model_exper} EXP01 ${arq_prev}

::

#======================================
# Climatology File
#

Use Climatology: ${use_climatologia}	  # 0-do not use, 1-use
# Diretory prefix mask sulfix
Climatology Model Id: 3
Climatology file: /stornext/online6/assim_dados/lucas.amarante/climatologiaJGM/climatologia50yr.%mc.bin

#======================================
# Precipitation File
#

Use Precipitation: ${use_precipitacao}	# 0-do not use, 1-use
# Diretory prefix mask sulfix
Precipitation Model Id: 5
Precipitation file: /stornext/online6/assim_dados/paulo.dias/Dados_SCAMTEC/preciptacao/%y4/3B42RT_SA.%y4%m2%d2%h200.bin
Define o Range do Histograma: 2                                         # exemplo: 2
Define valor do limite inferior da ultima classe do histograma: 70      # exemplo: 100
Define valor do minimo inferior da primeira classe do histograma: 0     # exemplo: 0
Define qual Precipitacao deseja avaliar: 16                             # exemplo: 16 para TOTAL ou 17 para CONVECTIVE
Define o periodo de acumulo de precpitacao da observacao: 3             # exemplo: 3 
Define o periodo de acumulo de precpitacao do experimento: 24           # exemplo: 24

#======================================
# Calculate EOFs
#
Use EOFs: ${use_eof}	# 0-do not use, 1-use
Define a quantidade de EOFs: 4           # exemplo: 4



#======================================================================
# OUTPUT
#

Output directory: ${saida_results}
EOT1


echo "Arquivo de controle criado com sucesso."
echo

echo "Copia do scamtec.conf para a area selecionada e experimento"  >> ${ARQlog}
echo                                                                >> ${ARQlog}
cat scamtec.conf                                                    >> ${ARQlog}                           
echo                                                                >> ${ARQlog}
echo                                                                >> ${ARQlog}

#=============================================================================================================

#Executando o SCAMTEC
echo "Executando o scamtec.x"
echo "        AGUARDE... "
echo

./scamtec.x >> ${ARQlog}


data=`date`
echo "Final do processo!!  ${data}"



echo "============================"  >> ${ARQlog}
echo                                 >> ${ARQlog}
echo "Final do processo:  ${data}"   >> ${ARQlog}
echo                                 >> ${ARQlog} 

echo
echo "Log da rodada se encontra no arquivo: ${ARQlog}"
echo "===================================================================================="

echo "Fim do processo !" 
echo


echo "Fim do processo para o recorte ${REC} conta ${USER}" >> ${ARQlog}
echo                                                       >> ${ARQlog}

#========================================================================================

#Executando o gerador de gráficos
echo "Executando o gerador de gráficos"
echo

cd ${dir_act}/core
cp plot_scamtec_results.gpl ${saida_results}
cd ${saida_results}
/scratchin/grupos/assim_dados/home/gdad/public/gnuplot5/bin/gnuplot -c ./plot_scamtec_results.gpl ${datai} ${dataf}


echo "Fim da geração dos gráficos"
echo

echo "Dados se encontram em: ${saida_results}" 
echo "Para vizualizar a figura digite evince plot_scamtec_results.eps "
echo




