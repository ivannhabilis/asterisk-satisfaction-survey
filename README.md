# Sistema de Pesquisa de Satisfação por Transferência para Asterisk (FreePBX/IncrediblePBX)

Este projeto implementa uma solução completa e confiável de pesquisa de satisfação pós-atendimento para PABX baseados em FreePBX e IncrediblePBX. O método utilizado é o de **transferência manual**, onde o agente, ao final do atendimento, transfere o cliente para um ramal virtual que inicia a URA de pesquisa.

Esta abordagem garante controle total ao agente e se integra de forma simples e robusta ao fluxo de chamadas do FreePBX, capturando os dados essenciais para a avaliação do atendimento.

## Funcionalidades Principais

- **URA de Pesquisa por Transferência:** Agente transfere a chamada para o ramal `*777` para iniciar a pesquisa.
- **Armazenamento Local:** Os resultados são salvos em um arquivo CSV simplificado no servidor.
- **Integração com Webhook:** Envia os dados da pesquisa em tempo real para uma URL externa em formato JSON.
- **Dashboard Web Integrado:** Um módulo para o painel do FreePBX permite:
    - Visualizar os resultados em uma tabela interativa com **paginação, busca e ordenação**.
    - Analisar a **nota média por agente** através de um gráfico.
    - Gerenciar a **URL do webhook** sem precisar de acesso SSH.
    - **Exportar** todos os dados para um arquivo CSV.
    - **Limpar** todo o histórico de dados com um clique.

---

## Fluxo da Chamada

1.  Um cliente liga e é atendido por um agente.
2.  Ao final da conversa, o agente decide oferecer a pesquisa de satisfação.
3.  O agente realiza uma **transferência (cega ou assistida) para o ramal `*777`**.
4.  O cliente é conectado à URA de pesquisa, ouve as instruções e digita uma nota de 1 a 5.
5.  O sistema executa duas ações:
    1.  Grava os dados (`data, hora, origem, agente, nota`) no arquivo `/var/log/asterisk/survey_results.csv`.
    2.  Envia os mesmos dados em formato JSON para o webhook configurado.
6.  Uma mensagem de agradecimento é reproduzida e a chamada do cliente é finalizada.

---

## Pré-requisitos

- Um PABX IncrediblePBX ou FreePBX funcional.
- Acesso ao terminal do servidor (SSH) com privilégios de root/sudo para a instalação.
- Áudios da URA previamente gravados no formato correto (**8000 Hz, 16-bit, Mono**).

---

## Parte 1: Instalação Automatizada

Este script de instalação foi revisado e simplificado. Ele irá configurar todo o ambiente necessário de forma rápida e segura.

### Passo 1: Preparar e Executar o Script

1.  Conecte-se ao seu servidor PABX via SSH.
2.  Crie o arquivo de instalação:
    ```bash
    nano install_survey.sh
    ```
3.  Copie e cole o conteúdo completo do script fornecido na seção **"Conteúdo dos Arquivos do Projeto"** abaixo. Salve e saia (`Ctrl+X`, `Y`, `Enter`).

4.  Torne o script executável:
    ```bash
    chmod +x install_survey.sh
    ```
5.  Execute o script com privilégios de superusuário:
    ```bash
    sudo ./install_survey.sh
    ```
O script cuidará de toda a criação de arquivos, configuração do dialplan e instalação do módulo web.

### Passo 2: Ações Manuais Pós-Instalação

1.  **Faça o Upload dos Áudios:**
    - Na interface web, vá em **Admin -> Sound Languages -> Custom Languages**.
    - Faça o upload dos seus três arquivos de áudio: `pesquisa-boas-vindas`, `pesquisa-agradecimento` e `pesquisa-opcao-invalida`.

2.  **Configure o Webhook:**
    - Acesse o novo dashboard em **Reports -> Pesquisa de Satisfação**.
    - Insira a URL do seu webhook e clique em "Salvar URL".

---

## Parte 2: Como Usar

A utilização do sistema é extremamente simples para o agente:

1.  Atenda uma chamada de cliente normalmente.
2.  Ao final da conversa, informe ao cliente que ele será transferido para uma breve pesquisa.
3.  Use a função de **transferência** do seu softphone ou telefone IP e transfira a chamada para o ramal:
    ```
    *777
    ```
A pesquisa será iniciada para o cliente, e o agente já pode encerrar sua parte da chamada.

---

## Parte 3: Guia de Publicação no GitHub

Siga estes passos para colocar este projeto em seu próprio repositório no GitHub.

1.  **Crie um Novo Repositório:**
    - Faça login no GitHub.
    - Clique no ícone `+` no canto superior direito e selecione **"New repository"**.
    - Dê um nome ao repositório (ex: `pabx-pesquisa-satisfacao`).
    - **Importante:** Marque a caixa **"Add a README file"**.

2.  **Clone o Repositório:**
    - Na página do seu novo repositório, clique no botão verde **"<> Code"** e copie a URL HTTPS.
    - No seu computador, abra um terminal e execute:
      ```bash
      git clone URL_QUE_VOCE_COPIOU
      ```
    - Entre na pasta do projeto:
      ```bash
      cd pabx-pesquisa-satisfacao
      ```

3.  **Adicione os Arquivos:**
    - Crie os arquivos do projeto dentro desta pasta (`install_survey.sh`, etc.). A maneira mais fácil é criar um arquivo `install_survey.sh` e copiar o conteúdo dele. Os outros arquivos estão contidos dentro do script de instalação.
    - Abra o arquivo `README.md` que o GitHub criou.
    - Apague o conteúdo padrão e **copie e cole todo este documento Markdown** dentro dele.
    - Salve o arquivo.

4.  **Envie as Alterações:**
    - No terminal, dentro da pasta do projeto, execute os seguintes comandos:
      ```bash
      # Adiciona todos os novos arquivos e alterações
      git add .
      
      # Cria um "pacote" de alterações com uma mensagem
      git commit -m "Versão inicial do projeto de pesquisa de satisfação"
      
      # Envia o pacote para o GitHub
      git push
      ```

**Pronto!** Seu projeto, com a documentação completa, está agora publicado no seu perfil do GitHub.

---

## Conteúdo dos Arquivos do Projeto (Para o `install_survey.sh`)

Copie todo o conteúdo abaixo e cole no seu arquivo `install_survey.sh`.

```bash
#!/bin/bash

# ==============================================================================
# Script de Instalação Automatizada - Módulo de Pesquisa por Transferência
# Versão Final
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
DIALPLAN_CUSTOM_CONF="${CONF_PATH}/extensions_custom.conf"

# --- Verificações Iniciais ---
if [ "$(id -u)" != "0" ]; then
   echo -e "${C_RED}Este script precisa ser executado como root. Use: sudo ./install_survey.sh${C_NC}" 1>&2
   exit 1
fi
if ! command -v fwconsole &> /dev/null; then
    echo -e "${C_RED}Comando 'fwconsole' não encontrado. Este script é para sistemas baseados em FreePBX.${C_NC}"
    exit 1
fi

echo -e "${C_BLUE}Iniciando a instalação do Módulo de Pesquisa de Satisfação...${C_NC}"

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

# export.php
read -r -d '' EXPORT_PHP_CONTENT <<'EOF'
<?php
if (!defined('FREEPBX_IS_AUTH')) { die('No direct script access allowed'); }
$survey_csv_file = '/var/log/asterisk/survey_results.csv';

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
    header("HTTP/1.0 404 Not Found");
    die("<h1>Erro 404</h1><p>O arquivo de relatório não foi encontrado ou não pode ser lido.</p>");
}
?>
EOF

# page.pesquisasatisfacao.php
read -r -d '' PAGE_PHP_CONTENT <<'EOF'
<?php
$webhook_conf_file = '/etc/asterisk/webhook_url.conf';
$survey_csv_file = '/var/log/asterisk/survey_results.csv';
$message = '';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['limpar_dados'])) {
        if (file_put_contents($survey_csv_file, '') !== false) {
            $message = '<div class="alert alert-success">Todos os dados da pesquisa foram limpos com sucesso!</div>';
        } else {
            $message = '<div class="alert alert-danger">Erro ao tentar limpar o arquivo de dados. Verifique as permissões.</div>';
        }
    }
    if (isset($_POST['webhook_url'])) {
        $new_url = trim($_POST['webhook_url']);
        if (filter_var($new_url, FILTER_VALIDATE_URL) || empty($new_url)) {
            file_put_contents($webhook_conf_file, $new_url);
            $message = '<div class="alert alert-success">URL do Webhook atualizada com sucesso!</div>';
        } else {
            $message = '<div class="alert alert-danger">URL inválida. Por favor, insira uma URL completa e válida.</div>';
        }
    }
}

$current_webhook_url = file_exists($webhook_conf_file) ? file_get_contents($webhook_conf_file) : '';

$agent_data = [];
if (file_exists($survey_csv_file) && ($handle = fopen($survey_csv_file, "r")) !== FALSE) {
    while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
        if (count($data) < 5) continue;
        $agent_exten = htmlspecialchars($data[3]);
        $score = intval($data[4]);
        if (!isset($agent_data[$agent_exten])) { $agent_data[$agent_exten] = ['total_score' => 0, 'count' => 0]; }
        $agent_data[$agent_exten]['total_score'] += $score;
        $agent_data[$agent_exten]['count']++;
    }
    fclose($handle);
}
$agent_chart_labels = []; $agent_chart_averages = [];
foreach ($agent_data as $agent => $data) {
    if ($data['count'] > 0) {
        $agent_chart_labels[] = "Ramal " . $agent;
        $agent_chart_averages[] = round($data['total_score'] / $data['count'], 2);
    }
}
?>

<!-- Inclusão das bibliotecas JS e CSS via CDN -->
<link rel="stylesheet" type="text/css" href="[https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap.min.css](https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap.min.css)"/>
<script type="text/javascript" src="[https://code.jquery.com/jquery-3.7.0.js](https://code.jquery.com/jquery-3.7.0.js)"></script>
<script type="text/javascript" src="[https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js](https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js)"></script>
<script type="text/javascript" src="[https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap.min.js](https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap.min.js)"></script>
<script src="[https://cdn.jsdelivr.net/npm/chart.js](https://cdn.jsdelivr.net/npm/chart.js)"></script>

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
                        <form method="POST" action="" class="form-horizontal">
                            <div class="form-group"><label for="webhook_url" class="col-md-3 control-label">URL do Webhook</label><div class="col-md-9">
                                <input type="text" class="form-control" id="webhook_url" name="webhook_url" value="<?php echo htmlspecialchars($current_webhook_url); ?>" placeholder="[https://seudominio.com/api/survey](https://seudominio.com/api/survey)">
                            </div></div>
                            <div class="form-group"><div class="col-md-offset-3 col-md-9"><button type="submit" class="btn btn-primary">Salvar URL</button></div></div>
                        </form>
                    </div>
                    <hr>
                    <div class="section-title"><h3><i class="fa fa-bar-chart"></i> Resultados Detalhados</h3></div>
                    <div class="container-fluid">
                        <div style="margin-bottom: 20px;">
                            <a href="/admin/modules/pesquisasatisfacao/export.php" class="btn btn-success"><i class="fa fa-download"></i> Exportar para CSV</a>
                            <form method="POST" action="" style="display: inline-block; margin-left: 10px;">
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
                                if (file_exists($survey_csv_file) && is_readable($survey_csv_file)) {
                                    $lines = file($survey_csv_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                                    $reversed_lines = array_reverse($lines);
                                    foreach ($reversed_lines as $line) {
                                        $data = str_getcsv($line);
                                        echo "<tr>";
                                        for ($i=0; $i < 5; $i++) { echo "<td>" . (isset($data[$i]) ? htmlspecialchars($data[$i]) : '') . "</td>"; }
                                        echo "</tr>";
                                    }
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
    const agentCtx = document.getElementById('agentChart');
    new Chart(agentCtx, { type: 'bar', data: { labels: <?php echo json_encode($agent_chart_labels); ?>, datasets: [{ label: 'Nota Média', data: <?php echo json_encode($agent_chart_averages); ?>, backgroundColor: 'rgba(54, 162, 235, 0.5)', borderColor: 'rgba(54, 162, 235, 1)', borderWidth: 1 }] }, options: { scales: { y: { beginAtZero: true, max: 5 } } } });
});
</script>
EOF

# send_survey_webhook.sh
read -r -d '' AGI_SCRIPT_CONTENT <<'EOF'
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
exten => *777,1,NoOp(--- Recebida transferência para Pesquisa de Satisfação ---)
same => n,Answer()
same => n,Goto(post-call-survey,s,1)

[post-call-survey]
exten => s,1,NoOp(Entrou na URA de pesquisa)
same => n,Answer()
same => n,Wait(1)
same => n,Read(SURVEY_SCORE,custom/pesquisa-boas-vindas,1,,3,5)
same => n,If($["${READSTATUS}" != "OK"]?Goto(hangup,1))
same => n,GotoIf($[${SURVEY_SCORE} < 1 | ${SURVEY_SCORE} > 5]?invalid)
same => n,System(/var/lib/asterisk/agi-bin/send_survey_webhook.sh "${SURVEY_SCORE}" "${TRANSFERER(callerid)}" "${CALLERID(num)}")
same => n,System(echo "${STRFTIME(${EPOCH},,%Y-%m-%d)},${STRFTIME(${EPOCH},,%H:%M:%S)},${CALLERID(num)},${TRANSFERER(callerid)},${SURVEY_SCORE}" >> /var/log/asterisk/survey_results.csv)
same => n,Playback(custom/pesquisa-agradecimento)
same => n,Hangup()
exten => invalid,1,Playback(custom/pesquisa-opcao-invalida)
same => n,Hangup()
exten => hangup,1,Hangup()
; ==============================================================================
; --- FIM: SISTEMA DE PESQUISA POR TRANSFERÊNCIA ---
; ==============================================================================
EOF

# --- Processo de Instalação ---
echo -e "\n${C_YELLOW}Passo 1/6: Criando diretórios...${C_NC}"
mkdir -p "$MODULE_PATH"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 2/6: Criando arquivos do projeto...${C_NC}"
echo "$XML_CONTENT" > "$MODULE_PATH/module.xml"
echo "$EXPORT_PHP_CONTENT" > "$MODULE_PATH/export.php"
echo "$PAGE_PHP_CONTENT" > "$MODULE_PATH/page.pesquisasatisfacao.php"
echo "$AGI_SCRIPT_CONTENT" > "$AGI_PATH/send_survey_webhook.sh"

if ! grep -q "; --- INÍCIO: SISTEMA DE PESQUISA POR TRANSFERÊNCIA ---" "$DIALPLAN_CUSTOM_CONF"; then
    # Faz backup antes de modificar
    cp "$DIALPLAN_CUSTOM_CONF" "${DIALPLAN_CUSTOM_CONF}.bak.$(date +%F)"
    echo "$DIALPLAN_CONTENT" >> "$DIALPLAN_CUSTOM_CONF"
    echo -e "${C_GREEN}Contextos do dialplan adicionados a ${DIALPLAN_CUSTOM_CONF}.${C_NC}"
else
    echo -e "${C_YELLOW}Contextos do dialplan já existem, pulando.${C_NC}"
fi

echo -e "\n${C_YELLOW}Passo 3/6: Criando arquivos de log e configuração...${C_NC}"
touch "$CONF_PATH/webhook_url.conf"
touch "$LOG_PATH/survey_results.csv"
touch "$LOG_PATH/survey_webhook.log"
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 4/6: Ajustando permissões...${C_NC}"
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
echo -e "${C_GREEN}OK!${C_NC}"

echo -e "\n${C_YELLOW}Passo 5/6: Instalando o módulo web...${C_NC}"
fwconsole ma install ${MODULE_NAME}

echo -e "\n${C_YELLOW}Passo 6/6: Recarregando configurações...${C_NC}"
fwconsole reload

echo -e "\n${C_GREEN}=====================================================${C_NC}"
echo -e "${C_GREEN}  INSTALAÇÃO CONCLUÍDA COM SUCESSO!                 ${C_NC}"
echo -e "${C_GREEN}=====================================================${C_NC}"
echo -e "\n${C_YELLOW}PRÓXIMOS PASSOS:${C_NC}"
echo -e "1. Faça o upload dos seus arquivos de áudio (.wav, 8kHz, 16-bit, Mono)."
echo -e "2. Acesse a interface web em ${C_BLUE}Reports -> Pesquisa de Satisfação${C_NC} para configurar o webhook."
echo -e "3. Para usar, transfira uma chamada para o ramal ${C_BLUE}*777${C_NC}."
