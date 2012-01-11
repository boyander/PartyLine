PartyLine Bash Implementation using SoX & Socat 
===============================================

Requirments
-----------
	- SoX v14.3.2
	- Socat v1.7.2.0


Scheme of implementation
------------------------
<img alt="PicSciP Demo Video" src="https://raw.github.com/boyander/PartyLine/master/images/esquema.png"/>

L'script conté dues parts, client i servidor. El servei del client rebrà els streams de 
àudio que tinguin com a destí el grup multicast i multiplexará cada
stream d’àudio cap a una “Named pipe” diferent. Mitjançant la
comanda play del paquet SoX reproduirem les FIFO que generi Socat.

La part de client es mes senzilla, ja que simplement mitjançant una
“Named Pipe” transferim el contingut gravat de l’entrada del sistema
multicast.


Contributors
------------
* [Marc Pomar Torres]

[Marc Pomar Torres]: http://bmat.com/company/index.php