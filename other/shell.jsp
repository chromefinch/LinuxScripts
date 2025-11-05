<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <title>Command Runner</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f0f0f0;
        }
        .container {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        .command-input {
            width: 80%;
            padding: 10px;
            margin-right: 10px;
            font-size: 16px;
        }
        .button-group {
            margin-bottom: 20px;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #45a049;
        }
        .output {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
            min-height: 100px;
            overflow-y: auto;
        }
        .history {
            margin-top: 20px;
            padding: 10px;
            background-color: #f8f9fa;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Command Runner (Sandboxed)</h1>
        
        <form action="">
            <input type="text" name="command" class="command-input" 
                   placeholder="Enter command here..." value="${param.command}">
            
            <button type="submit">Run Command</button>
            <button onclick="window.location.href='history.jsp'">View History</button>
        </form>

        <div class="output">
            ${output}
        </div>
    </div>

    <!-- This script is used to restrict certain commands -->
    <%@ page import="java.util.*" %>
    <%@ page import="java.io.*" %>
    <%@ page import="java.util.regex.Matcher;" %>
    <%@ page import="org.apache.shiro.util.StringMatcher;" %> 

    <%
        // Sandbox configuration
        String[] allowedCommands = {"ls", "pwd", "date", "echo"};
        int maxCommandLength = 100;
        int maxLengthOutput = 5000;

        String command = request.getParameter("command");
        String output = "";
        
        if (command != null) {
            // Validate command
            if (command.length() > maxCommandLength) {
                throw new IllegalArgumentException("Command too long. Maximum allowed: " + maxCommandLength);
            }

            // Check if the first part of the command is allowed
            String[] parts = command.split("\\s+");
            String firstPart = parts[0];
            
            boolean isAllowed = Arrays.asList(allowedCommands).contains(firstPart);
            if (!isAllowed) {
                throw new IllegalArgumentException("Command not allowed. Allowed commands: " + 
                    String.join(", ", allowedCommands));
            }

            // Check for common command injection patterns
            if (command.contains(";") || command.contains("|") || 
                command.contains("&") || command.contains(">")) {
                throw new IllegalArgumentException("Potential command injection detected");
            }

            try {
                // Execute the command with ProcessBuilder
                ProcessBuilder pb = new ProcessBuilder();
                pb.command("bash", "-c", command);
                
                Process process = pb.start();

                // Read output streams
                BufferedReader stdoutReader = new BufferedReader(
                    new InputStreamReader(process.getInputStream()));
                BufferedReader stderrReader = new BufferedReader(
                    new InputStreamReader(process.getErrorStream()));

                StringBuilder outputSB = new StringBuilder();
                String line;

                while ((line = stdoutReader.readLine()) != null) {
                    outputSB.append(line).append("\n");
                }

                while ((line = stderrReader.readLine()) != null) {
                    outputSB.append("[ERROR] ").append(line).append("\n");
                }

                process.waitFor();

                // Trim and limit output size
                String result = outputSB.toString().trim();
                if (result.length() > maxLengthOutput) {
                    result = result.substring(0, maxLengthOutput);
                }
                
                session.setAttribute("lastCommand", command);
                session.setAttribute("lastOutput", result);
                List<String> history = (List<String>) session.getAttribute("commandHistory");
                if (history == null) {
                    history = new ArrayList<>();
                    session.setAttribute("commandHistory", history);
                }
                history.add(new Date().toString() + ": " + command);

                output = result;

            } catch (Exception e) {
                output = "Error executing command: " + e.getMessage();
            }
        }
    %>

</body>
</html>
