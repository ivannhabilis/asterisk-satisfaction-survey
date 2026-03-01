<?php
$survey_csv_file = __DIR__ . '/survey_results.csv';
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
        $webhook_conf_file = __DIR__ . '/webhook_url.conf';
        $new_url = trim($_POST['webhook_url']);
        if (filter_var($new_url, FILTER_VALIDATE_URL) || empty($new_url)) {
            file_put_contents($webhook_conf_file, $new_url);
            $message = '<div class="alert alert-success">URL do Webhook atualizada com sucesso!</div>';
        } else {
            $message = '<div class="alert alert-danger">URL inválida. Por favor, insira uma URL completa e válida.</div>';
        }
    }
}

$current_webhook_url = file_exists(__DIR__ . '/webhook_url.conf') ? file_get_contents(__DIR__ . '/webhook_url.conf') : '';
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

<h2>Satisfaction Survey Dashboard (Preview)</h2>
<?php echo $message; ?>

<div class="container-fluid">
    <div class="row">
        <div class="col-sm-12">
            <div class="fpbx-container">
                <div class="display full-border">
                    <div class="section-title"><h3><i class="fa fa-pie-chart"></i> Análise Gráfica</h3></div>
                    <div class="container-fluid"><div class="row"><div class="col-md-6">
                        <h4>Nota Média por Ramal</h4>
                        <canvas id="agentChart"></canvas>
                    </div></div></div>
                    <hr>
                    <div class="section-title"><h3><i class="fa fa-cogs"></i> Configuração do Webhook</h3></div>
                    <div class="container-fluid">
                        <form method="POST" action="preview_page.php" class="form-horizontal">
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
                            <a href="preview_page.php?action=export" class="btn btn-success"><i class="fa fa-download"></i> Exportar para CSV</a>
                            <form method="POST" action="preview_page.php" style="display: inline-block; margin-left: 10px;">
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
                                <li><strong>Ramal:</strong> O ramal que transferiu a chamada para a pesquisa.</li>
                                <li><strong>Nota:</strong> A nota de 1 a 5 fornecida pelo cliente.</li>
                            </ul>
                        </div>
                        <table id="surveyTable" class="table table-striped table-bordered" style="width:100%">
                            <thead><tr><th>Data</th><th>Hora</th><th>Origem</th><th>Ramal</th><th>Nome do ramal</th><th>Nota</th></tr></thead>
                            <tbody>
                                <?php
                                $reversed_rows = array_reverse($all_rows);
                                foreach ($reversed_rows as $data) {
                                    echo "<tr>";
                                    for ($i=0; $i < 6; $i++) { echo "<td>" . (isset($data[$i]) ? htmlspecialchars($data[$i]) : '') . "</td>"; }
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
                    label: 'Average Score',
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
