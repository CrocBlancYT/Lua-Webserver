
//UPLOAD FOR FILES
const fileInput = document.querySelector("input[type=file]");

function POST_file(fileName, content) {
    fetch('/file-host', {
        method: "POST",
        headers: {
            "Content-Length" : toString(content.length),
            "Target-Name" : fileName
        },
        body: content
    });
}


function onContent(file, onLoaded) {
    var reader = new FileReader();
    reader.onload = function(){
        var dataURL = reader.result;
        onLoaded(dataURL)
    };
    reader.readAsDataURL(file);
};

fileInput.addEventListener("change", async () => {
    const [file] = fileInput.files;

    if (file) {
        //console.log(file.encoding)

        //downloadFile(file.name, file)
        onContent(file, function(dataURL) {
            POST_file(file.name, dataURL)
        })
    }
});

//DOWNLOAD FOR FILES
function downloadFile(fileName, file) {
    var a = document.createElement("a");
    a.href = URL.createObjectURL(file);
    a.setAttribute("download", fileName);
    a.click();
}

function deleteFile() {
    
}

var list = document.getElementById('file-list')

function refreshHTML(fileList) {
    var html = '\n        '

    function addElement(value, index, array) {
        var download_id = 'download_'+index
        var delete_id = 'delete_'+index
        
        html = html + '<li>'+value['name']+' ('+value['size']+'o) <button id='+download_id+'>Download</button> <button id='+delete_id+'>Delete</button></li>\n    '
    }

    fileList.forEach(addElement)
    list.innerHTML = html

    fileList.forEach(function(value, index, array) {
        var download_id = 'download_'+index
        var delete_id = 'delete_'+index

        var download_button = document.getElementById(download_id)
        var delete_button = document.getElementById(delete_id)
        
        download_button.onclick = function() {
            console.log('download '+index)
        }

        delete_button.onclick = function() {
            console.log('delete '+index)
        }
    })
}

function getFileList(onLoad) {
    fetch('/file-host', {
        method: "GET",
        headers: {
            ['Target-Name'] : '.'
        }
    }).then(onLoad)
}

function refreshList() {
    getFileList(function(response) {
        response.json().then(function(data) {
            refreshHTML(data)
        })
    })
}

refreshList() 