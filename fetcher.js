async function download(){
   const response = await fetch("https://gist.githubusercontent.com/samithaf/d0f343c12be293a92a08d2286e94c268/raw/384c8332144a97d22981a7e8cb009ae277d64802/Dockerfile", {
      method: 'GET'
   })
   const buffer = await response.arrayBuffer()
   fs.writeFileSync(`file${i}.txt`, Buffer.from(buffer))  
}
download()
