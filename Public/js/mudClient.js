var input = document.getElementById("textToSend");

var openConnectionButton = document.getElementById("openConnectionButton");
var closeConnectionButton = document.getElementById("closeConnectionButton");

var pid;
var sessionID = "";
//console.log(input)
var ws = new WebSocket('ws://localhost:8080/game')
ws.onopen = () => {
    console.log('ws opened on browser')
    openConnectionButton.hidden = true
    closeConnectionButton.hidden = false
    document.getElementById("pid").innerText = "Not logged in."
}

ws.onmessage = (message) => {
    let m = JSON.parse(message.data);

    if (m.type == "SessionMessage") {
    sessionID = m.sessionID
    }

    if (m.type == "Message") {
    var content = document.getElementById("content");
    content.innerHTML += "<p>" + m.message + "</p>";

    if (pid) { document.getElementById("pid").innerText = "User ID: " + pid } else {
        document.getElementById("pid").innerText = "Not logged in."
    }
    }

    console.log(`message received`, m);
}

function sendText(text) {
    let m = {
    type: "Message",
    playerID: sessionID,
    message: text
    }
    ws.send(JSON.stringify(m))
    input.value = "";
}

function sendInputText() {
    sendText(input.value)
}

function closeConnection() {
    content.innerHTML += "<p>CONNECTION CLOSED</p>";
    ws.close();
    openConnectionButton.hidden = false
    closeConnectionButton.hidden = true
}

function openConnection() {
    window.location.reload();
    //console.log("attempt to reopen connection.")
    //ws = new WebSocket('ws://localhost:8080/game')
}