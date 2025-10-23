#!/bin/bash

# ==============================================================================
# Script de Instalação Automatizada - Módulo de Pesquisa por Transferência
# Versão Final e Consolidada
# ==============================================================================

# --- Definição de Cores ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m'

# --- Variáveis ---
MODULE_NAME="pesquisasatisfacao"
MODULE_PATH="/var/www/html/admin/modules/${MODULE_NAME}"
AGI_PATH="/var/lib/asterisk/agi-bin"
CONF_PATH="/etc/asterisk"
LOG_PATH="/var/log/asterisk"
AUDIO_PATH_PT_BR="/var/lib/asterisk/sounds/pt_BR/custom"
DIALPLAN_CUSTOM_CONF="${CONF_PATH}/extensions_custom.conf"

# --- Verificações Iniciais ---
if [ "$(id -u)" != "0" ]; then
   echo -e "${C_RED}Este script precisa ser executado como root. Use: sudo ./install.sh${C_NC}" 1>&2
   exit 1
fi
if ! command -v fwconsole &> /dev/null; then
    echo -e "${C_RED}Comando 'fwconsole' não encontrado. Este script é para sistemas baseados em FreePBX.${C_NC}"
    exit 1
fi
if [ ! -d "audio" ]; then
    echo -e "${C_RED}Diretório 'audio/' não encontrado. Certifique-se de que a pasta com os arquivos de áudio existe.${C_NC}"
    exit 1
fi

echo -e "${C_BLUE}=====================================================${C_NC}"
echo -e "${C_BLUE}Iniciando a instalação do Módulo de Pesquisa de Satisfação...${C_NC}"
echo -e "${C_BLUE}=====================================================${C_NC}"

# --- HEREDOCS com o conteúdo dos arquivos ---

# module.xml
read -r -d '' XML_CONTENT <<'EOF'
<module>
    <rawname>pesquisasatisfacao</rawname>
    <name>Pesquisa de Satisfação</name>
    <version>3.0.0</version>
    <type>tool</type>
    <category>Reports</category>
    <description>Dashboard para a pesquisa de satisfação por transferência.</description>
    <menuitems>
        <pesquisasatisfacao>Pesquisa de Satisfação</pesquisasatisfacao>
    </menuitems>
</module>
EOF

# page.pesquisasatisfacao.php
read -r -d '' PAGE_PHP_CONTENT <<'EOF'
<?php
$survey_csv_file = '/var/log/asterisk/survey_results.csv';
$message = '';

if (isset($_GET['action']) && $_GET['action'] == 'export') {
    if (file_exists($survey_csv_file) && is_readable($survey_csv_file)) {
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="relatorio_pesquisa_'.date('Y-m-d').'.csv"');
        header('Pragma: no-cache');
        header('Expires: 0');
        ob_clean();
        flush();
        readfile($survey_csv_file);
        exit;
    } else {
        die("Erro: O arquivo de relatório não foi encontrado ou não pode ser lido.");
    }
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['limpar_dados'])) {
        if (file_put_contents($survey_csv_file, '') !== false) {
            $message = '<div class="alert alert-success">Todos os dados da pesquisa foram limpos com sucesso!</div>';
        } else {
            $message = '<div class="alert alert-danger">Erro ao tentar limpar o arquivo de dados. Verifique as permissões.</div>';
        }
    }
    if (isset($_POST['webhook_url'])) {
        $webhook_conf_file = '/etc/asterisk/webhook_url.conf';
        $new_url = trim($_POST['webhook_url']);
        if (filter_var($new_url, FILTER_VALIDATE_URL) || empty($new_url)) {
            file_put_contents($webhook_conf_file, $new_url);
            $message = '<div class="alert alert-success">URL do Webhook atualizada com sucesso!</div>';
        } else {
            $message = '<div class="alert alert-danger">URL inválida. Por favor, insira uma URL completa e válida.</div>';
        }
    }
}

$current_webhook_url = file_exists('/etc/asterisk/webhook_url.conf') ? file_get_contents('/etc/asterisk/webhook_url.conf') : '';
$agent_data = [];
$all_rows = [];

if (file_exists($survey_csv_file) && is_readable($survey_csv_file)) {
    if (($handle = fopen($survey_csv_file, "r")) !== FALSE) {
        while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
            if (!empty($data)) {
                $all_rows[] = $data;
            }
        }
        fclose($handle);
    }
}

foreach ($all_rows as $data) {
    if (isset($data[3], $data[4]) && trim($data[3]) !== '' && is_numeric(trim($data[4]))) {
        $agent_exten = htmlspecialchars(trim($data[3]));
        $score = intval(trim($data[4]));
        if (!isset($agent_data[$agent_exten])) { $agent_data[$agent_exten] = ['total_score' => 0, 'count' => 0]; }
        $agent_data[$agent_exten]['total_score'] += $score;
        $agent_data[$agent_exten]['count']++;
    }
}

$agent_chart_labels = []; $agent_chart_averages = [];
foreach ($agent_data as $agent => $data) {
    if ($data['count'] > 0) {
        $agent_chart_labels[] = "Ramal " . $agent;
        $agent_chart_averages[] = round($data['total_score'] / $data['count'], 2);
    }
}
?>

<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap.min.css"/>
<script type="text/javascript" src="https://code.jquery.com/jquery-3.7.0.js"></script>
<script type="text/javascript" src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script type="text/javascript" src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<h2>Dashboard da Pesquisa de Satisfação</h2>
<?php echo $message; ?>

<div class="container-fluid">
    <div class="row">
        <div class="col-sm-12">
            <div class="fpbx-container">
                <div class="display full-border">
                    <div class="section-title"><h3><i class="fa fa-pie-chart"></i> Análise Gráfica</h3></div>
                    <div class="container-fluid"><div class="row"><div class="col-md-6">
                        <h4>Nota Média por Agente</h4>
                        <canvas id="agentChart"></canvas>
                    </div></div></div>
                    <hr>
                    <div class="section-title"><h3><i class="fa fa-cogs"></i> Configuração do Webhook</h3></div>
                    <div class="container-fluid">
                        <form method="POST" action="config.php?display=pesquisasatisfacao" class="form-horizontal">
                            <div class="form-group"><label for="webhook_url" class="col-md-3 control-label">URL do Webhook</label><div class="col-md-9">
                                <input type="text" class="form-control" id="webhook_url" name="webhook_url" value="<?php echo htmlspecialchars($current_webhook_url); ?>" placeholder="https://seudominio.com/api/survey">
                            </div></div>
                            <div class="form-group"><div class="col-md-offset-3 col-md-9"><button type="submit" class="btn btn-primary">Salvar URL</button></div></div>
                        </form>
                    </div>
                    <hr>
                    <div class="section-title"><h3><i class="fa fa-bar-chart"></i> Resultados Detalhados</h3></div>
                    <div class="container-fluid">
                        <div style="margin-bottom: 20px;">
                            <a href="config.php?display=pesquisasatisfacao&action=export" class="btn btn-success"><i class="fa fa-download"></i> Exportar para CSV</a>
                            <form method="POST" action="config.php?display=pesquisasatisfacao" style="display: inline-block; margin-left: 10px;">
                                <button type="submit" name="limpar_dados" value="1" class="btn btn-danger" onclick="return confirm('Tem certeza de que deseja apagar TODOS os dados da pesquisa? Esta ação não pode ser desfeita.');">
                                    <i class="fa fa-trash"></i> Limpar Dados
                                </button>
                            </form>
                        </div>
                        <div class="well">
                            <strong>Legenda das Colunas:</strong>
                            <ul>
                                <li><strong>Data e Hora:</strong> Quando a pesquisa foi respondida.</li>
                                <li><strong>Origem:</strong> O número de telefone (Caller ID) do cliente.</li>
                                <li><strong>Agente:</strong> O ramal do agente que transferiu a chamada para a pesquisa.</li>
                                <li><strong>Nota:</strong> A nota de 1 a 5 fornecida pelo cliente.</li>
                            </ul>
                        </div>
                        <table id="surveyTable" class="table table-striped table-bordered" style="width:100%">
                            <thead><tr><th>Data</th><th>Hora</th><th>Origem</th><th>Agente</th><th>Nota</th></tr></thead>
                            <tbody>
                                <?php
                                $reversed_rows = array_reverse($all_rows);
                                foreach ($reversed_rows as $data) {
                                    echo "<tr>";
                                    for ($i=0; $i < 5; $i++) { echo "<td>" . (isset($data[$i]) ? htmlspecialchars($data[$i]) : '') . "</td>"; }
                                    echo "</tr>";
                                }
                                ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
<script>
$(document).ready(function() {
    $('#surveyTable').DataTable({ "language": { "url": "//cdn.datatables.net/plug-ins/1.13.6/i18n/pt-BR.json" }, "order": [[0, "desc"], [1, "desc"]] });
    var agentLabels = <?php echo json_encode($agent_chart_labels); ?>;
    var agentAverages = <?php echo json_encode($agent_chart_averages); ?>;
    if (agentLabels.length > 0) {
        const agentCtx = document.getElementById('agentChart');
        new Chart(agentCtx, {
            type: 'bar',
            data: {
                labels: agentLabels,
                datasets: [{
                    label: 'Nota Média',
                    data: agentAverages,
                    backgroundColor: 'rgba(54, 162, 235, 0.5)',
                    borderColor: 'rgba(54, 162, 235, 1)',
                    borderWidth: 1
                }]
            },
            options: { scales: { y: { beginAtZero: true, max: 5 } } }
        });
    } else {
        $('#agentChart').parent().html('<p class="alert alert-info">Não há dados suficientes ou válidos para exibir o gráfico.</p>');
    }
});
</script>
EOF

# send_survey_webhook.sh
read -r -d '' WEBHOOK_SCRIPT_CONTENT <<'EOF'
#!/bin/bash
SURVEY_SCORE="$1"
AGENT_EXTEN="$2"
CALLERIDNUM="$3"

WEBHOOK_URL=$(cat /etc/asterisk/webhook_url.conf)

if [ -n "${WEBHOOK_URL}" ]; then
    JSON_PAYLOAD=$(cat <<JSON
    {
      "agente_ramal": "${AGENT_EXTEN}",
      "data": "$(date +'%Y-%m-%d')",
      "hora": "$(date +'%H:%M:%S')",
      "origem": "${CALLERIDNUM}",
      "nota_pesquisa": "${SURVEY_SCORE}"
    }
JSON
    )
    curl -s -X POST -H "Content-Type: application/json" -d "${JSON_PAYLOAD}" "${WEBHOOK_URL}" --max-time 5 >> /var/log/asterisk/survey_webhook.log 2>&1
fi
exit 0
EOF

# Dialplan a ser adicionado
read -r -d '' DIALPLAN_CONTENT <<'EOF'

; ==============================================================================
; --- INÍCIO: SISTEMA DE PESQUISA POR TRANSFERÊNCIA (Adicionado por script) ---
; ==============================================================================
[from-internal-custom]
exten => _*777!,1,NoOp(--- Recebida transferência para Pesquisa de Satisfação ---)
same => n,Answer()
same => n,Wait(1)
same => n,Set(AGENT_EXTEN=${EXTEN:4})
same => n,Read(SURVEY_SCORE,custom/pesquisa-boas-vindas,1,,3,5)
same => n,GotoIf($["${READSTATUS}" != "OK"]?Hangup())
same => n,GotoIf($[${SURVEY_SCORE} < 1 | ${SURVEY_SCORE} > 5]?invalid)
;same => n,System(echo "${STRFTIME(${EPOCH},,%Y-%m-%d)},${STRFTIME(${EPOCH},,%H:%M:%S)},${CALLERID(num)},${TRANSFERER(callerid)},${SURVEY_SCORE}" >> /var/log/asterisk/survey_results.csv)
;same => n,System(/var/lib/asterisk/agi-bin/send_survey_webhook.sh "${SURVEY_SCORE}" "${TRANSFERER(callerid)}" "${CALLERID(num)}" &)
same => n,System(echo "${STRFTIME(${EPOCH},,%Y-%m-%d)},${STRFTIME(${EPOCH},,%H:%M:%S)},${CALLERID(num)},${AGENT_EXTEN},${SURVEY_SCORE}" >> /var/log/asterisk/survey_results.csv)
same => n,System(/var/lib/asterisk/agi-bin/send_survey_webhook.sh "${SURVEY_SCORE}" "${AGENT_EXTEN}" "${CALLERID(num)}" &)
same => n,Playback(custom/pesquisa-agradecimento)
same => n,Hangup()
same => n(invalid),Playback(custom/pesquisa-opcao-invalida)
same => n,Hangup()

; ==============================================================================
; --- FIM: SISTEMA DE PESQUISA POR TRANSFERÊNCIA ---
; ==============================================================================
EOF

# --- Início do Processo de Instalação ---
echo -e "\n${C_YELLOW}Passo 1/7: Criando diretórios...${C_NC}"
mkdir -p "$MODULE_PATH"
mkdir -p "$AUDIO_PATH_PT_BR"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 2/7: Copiando arquivos de áudio...${C_NC}"
cp audio/pesquisa-*.wav "${AUDIO_PATH_PT_BR}/"
echo -e "${C_GREEN}Áudios copiados para ${AUDIO_PATH_PT_BR}${C_NC}"

echo -e "\n${C_YELLOW}Passo 3/7: Criando arquivos do projeto...${C_NC}"
echo "$XML_CONTENT" > "$MODULE_PATH/module.xml"
echo "$PAGE_PHP_CONTENT" > "$MODULE_PATH/page.pesquisasatisfacao.php"
echo "$WEBHOOK_SCRIPT_CONTENT" > "$AGI_PATH/send_survey_webhook.sh"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 4/7: Configurando o dialplan...${C_NC}"
if ! grep -q "; --- INÍCIO: SISTEMA DE PESQUISA POR TRANSFERÊNCIA ---" "$DIALPLAN_CUSTOM_CONF"; then
    cp "$DIALPLAN_CUSTOM_CONF" "${DIALPLAN_CUSTOM_CONF}.bak.$(date +%F)"
    # Limpa contextos antigos e adiciona o novo
    sed -i '/; --- INÍCIO: SISTEMA DE PESQUISA/,/; --- FIM: SISTEMA DE PESQUISA/d' "$DIALPLAN_CUSTOM_CONF"
    sed -i '/\[post-call-survey\]/,/exten => hangup,1,Hangup()/d' "$DIALPLAN_CUSTOM_CONF"
    echo "$DIALPLAN_CONTENT" >> "$DIALPLAN_CUSTOM_CONF"
    echo -e "${C_GREEN}Contextos do dialplan configurados em ${DIALPLAN_CUSTOM_CONF}.${C_NC}"
else
    echo -e "${C_YELLOW}Contextos do dialplan já existem, pulando.${C_NC}"
fi

echo -e "\n${C_YELLOW}Passo 5/7: Criando arquivos de log e configuração...${C_NC}"
touch "$CONF_PATH/webhook_url.conf"
touch "$LOG_PATH/survey_results.csv"
touch "$LOG_PATH/survey_webhook.log"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 6/7: Ajustando permissões...${C_NC}"
WEB_USER="apache"
if ! id -g "$WEB_USER" &>/dev/null; then WEB_USER="www-data"; fi
chown -R asterisk:asterisk "$MODULE_PATH"
chmod 755 "$AGI_PATH/send_survey_webhook.sh"
chown asterisk:asterisk "$AGI_PATH/send_survey_webhook.sh"
chown asterisk:$WEB_USER "$CONF_PATH/webhook_url.conf"
chmod 664 "$CONF_PATH/webhook_url.conf"
chown asterisk:asterisk "$LOG_PATH/survey_results.csv"
chown asterisk:asterisk "$LOG_PATH/survey_webhook.log"
chmod 664 "$LOG_PATH/survey_results.csv"
chown asterisk:asterisk "${AUDIO_PATH_PT_BR}/pesquisa-*.wav"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 7/7: Instalando e recarregando...${C_NC}"
fwconsole ma install ${MODULE_NAME}
fwconsole reload

echo -e "\n${C_GREEN}=====================================================${C_NC}"
echo -e "${C_GREEN}  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                 ${C_NC}"
echo -e "${C_GREEN}=====================================================${C_NC}"
echo -e "\n${C_YELLOW}PRÓXIMOS PASSOS:${C_NC}"
echo -e "1. Acesse a interface web em ${C_BLUE}Reports -> Pesquisa de Satisfação${C_NC} para configurar o webhook."
echo -e "2. Para usar, transfira uma chamada para o ramal ${C_BLUE}*777${C_NC}."
